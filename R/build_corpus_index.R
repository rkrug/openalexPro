#' Build a Parquet index for fast ID lookups in a parquet corpus
#'
#' This function creates a Parquet index that maps OpenAlex IDs
#' to their physical location in the parquet corpus. This enables fast random
#' access to specific records without scanning entire partitions.
#'
#' The index file will be created in the same directory as the `corpus_dir` and
#' has to stay there for the lookup to function. Together with the `corpus_dir`,
#' the index file can be moved to any location.
#'
#' The function is memory-efficient and can handle 300M+ records by using
#' a two-stage approach: first indexing each parquet file individually
#' (bounded memory per file), then combining into a single parquet index
#' file. This avoids loading the entire dataset at once.
#' Stage 1 is parallelized using [future.apply::future_lapply()] and
#' supports resuming if interrupted. On macOS, a `.metadata_never_index`
#' file is created in the temporary directory to prevent Spotlight from
#' indexing the parquet files during building.
#'
#' @param corpus_dir Path to the parquet corpus directory.
#' @param memory_limit DuckDB memory limit (e.g., "20GB"). Default is `NULL`.
#' @param workers Number of parallel workers for Stage 1 indexing and DuckDB
#'   threads for Stage 2. Default is `NULL` (use all cores).
#'
#' @return Invisibly returns the path to the created index.
#'
#' @details
#' The index contains the following columns:
#' \describe{
#'   \item{id}{The OpenAlex ID}
#'   \item{id_block}{Block number computed as `floor(numeric_id / 10000)`}
#'   \item{parquet_file}{Relative path to the parquet file in the corpus}
#'   \item{file_row_number}{Row number within the file (0-indexed)}
#' }
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery
#' @importFrom duckdb duckdb
#' @importFrom future plan multisession sequential
#' @importFrom future.apply future_lapply
#' @importFrom progressr with_progress progressor
#'
#' @examples
#' \dontrun{
#' # Build partitioned index for OpenAlex IDs (fast O(1) lookup)
#' build_corpus_index(
#'   corpus_dir = "/Volumes/openalex/parquet/works",
#'   memory_limit = "20GB"
#' )
#' }
#'
#' @export
#' @md
build_corpus_index <- function(
  corpus_dir,
  memory_limit = NULL,
  workers = NULL
) {
  if (!dir.exists(corpus_dir)) {
    stop("corpus_dir does not exist: ", corpus_dir)
  }

  corpus_dir <- normalizePath(corpus_dir)

  snapshot_dir <- dirname(corpus_dir)
  corpus_name <- basename(corpus_dir)

  index_file <- file.path(snapshot_dir, paste0(corpus_name, "_id_idx.parquet"))

  if (file.exists(index_file)) {
    message(
      "index_file exists - creation skipped - delete manually to re-create: ",
      index_file
    )
    return(invisible(NULL))
  }

  index_file <- sub("/+$", "", index_file)

  con <- DBI::dbConnect(duckdb::duckdb(), read_only = FALSE)

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE),
    add = TRUE
  )

  ## Apply performance settings
  DBI::dbExecute(conn = con, "SET preserve_insertion_order = false")
  if (!is.null(memory_limit)) {
    DBI::dbExecute(
      conn = con,
      paste0("SET memory_limit = '", memory_limit, "'")
    )
  }
  if (!is.null(workers)) {
    DBI::dbExecute(
      conn = con,
      paste0("SET threads = ", workers)
    )
  }

  message("Building index from: ", corpus_dir)
  message("    Writing to: ", index_file)

  total_start <- Sys.time()

  ## Two-stage approach:
  ##   Stage 1: Index each parquet file individually (bounded memory, parallel)
  ##   Stage 2: Combine into a sibngle .parquet file

  ## OpenAlex ID formats:
  ##   https://openalex.org/W1234567890  (standard: letter + digits)
  ##   https://openalex.org/domains/2    (path-based: entity_type/digits)
  ##   https://openalex.org/subfields/2208
  ## Use regexp_extract to get the trailing numeric part from any format
  ## id_block = floor(numeric_id / 10000)

  temp_dir <- paste0(index_file, "_tmp")
  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(temp_dir, ".metadata_never_index"))

  parquet_files <- list.files(
    corpus_dir,
    pattern = "\\.parquet$",
    recursive = TRUE,
    full.names = TRUE
  )

  ## Depth of snapshot_dir in path hierarchy — used to extract relative paths
  ## inside future_lapply without string-matching absolute paths.
  ## normalizePath() on Windows can return 8.3 short names (e.g. RUNNER~1)
  ## for some calls and long names (runneradmin) for others, making string
  ## comparison unreliable. Counting components is immune to this. ----
  snapshot_dir_fwd <- gsub("\\\\", "/", snapshot_dir)
  snapshot_depth   <- length(strsplit(snapshot_dir_fwd, "/")[[1]])

  ## Stage 1: Index each file individually (parallel)
  message(
    "Stage 1: Indexing ",
    length(parquet_files),
    " parquet files",
    if (!is.null(workers) && workers > 1) {
      paste0(" with ", workers, " workers...")
    } else {
      " sequentially..."
    }
  )

  ## Set up parallel plan if workers > 1
  if (!is.null(workers) && workers > 1) {
    old_plan <- future::plan(future::multisession, workers = workers)
    on.exit(future::plan(old_plan), add = TRUE)
  }

  progressr::with_progress({
    p <- progressr::progressor(along = parquet_files)
    future.apply::future_lapply(seq_along(parquet_files), function(i) {
      pf <- parquet_files[i]
      out_file <- file.path(
        temp_dir,
        paste0("idx_", sprintf("%05d", i), ".parquet")
      )

      ## Resume support: skip already indexed files
      if (file.exists(out_file)) {
        p()
        return(invisible(NULL))
      }

      ## Each worker gets its own DuckDB connection
      worker_con <- DBI::dbConnect(duckdb::duckdb(), read_only = FALSE)
      on.exit(DBI::dbDisconnect(worker_con, shutdown = TRUE))
      DBI::dbExecute(conn = worker_con, "SET threads = 1")
      DBI::dbExecute(
        conn = worker_con,
        "SET preserve_insertion_order = false"
      )
      if (!is.null(memory_limit)) {
        DBI::dbExecute(
          conn = worker_con,
          paste0("SET memory_limit = '", memory_limit, "'")
        )
      }

      ## Compute relative path from snapshot_dir using component depth.
      ## This avoids embedding snapshot_dir in a SQL regex (backslashes on
      ## Windows break regex) and avoids string-matching absolute paths
      ## (8.3 short-name vs long-name mismatch). ----
      pf_parts <- strsplit(gsub("\\\\", "/", pf), "/")[[1]]
      rel_path <- paste(
        pf_parts[seq(snapshot_depth + 1L, length(pf_parts))],
        collapse = "/"
      )

      stage1_query <- paste0(
        "COPY (",
        "SELECT ",
        "  id, ",
        "  CAST(FLOOR(CAST(regexp_extract(id, '(\\d+)$', 1) AS BIGINT) / 10000) AS INTEGER) ",
        "    AS id_block, ",
        "  '", rel_path, "' AS parquet_file,",
        "  file_row_number ",
        "FROM read_parquet('",
        pf,
        "', file_row_number = true)",
        ") TO '",
        out_file,
        "' (FORMAT PARQUET, COMPRESSION SNAPPY)"
      )
      DBI::dbExecute(conn = worker_con, stage1_query)
      p()
      invisible(NULL)
    })
  }, handlers = progressr::handler_cli())

  message("    Stage 1 complete.")

  message("Stage 2: Combining into single index file ", index_file)

  copy_query <- paste0(
    "COPY (",
    "  SELECT * ",
    "  FROM read_parquet('",
    temp_dir,
    "')",
    ") TO '",
    index_file,
    "' (FORMAT PARQUET, COMPRESSION SNAPPY)"
  )

  dbExecute(con, copy_query)

  # arrow::open_dataset(temp_dir) |>
  #   arrow::write_parquet(index_file, compression = "snappy")

  unlink(temp_dir, recursive = TRUE)

  index_files <- index_file
  total_size <- sum(file.info(index_files)$size)
  file_size_gb <- round(total_size / 1024^3, 2)

  message(
    "Done! Index size: ",
    file_size_gb,
    " GB in one partition files"
  )

  message(
    "Total time: ",
    round(difftime(Sys.time(), total_start, units = "mins"), 2),
    " minutes"
  )

  invisible(index_file)
}
