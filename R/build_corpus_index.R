#' Build a Parquet index for fast ID lookups in a parquet corpus
#'
#' This function creates a Parquet index that maps OpenAlex IDs
#' to their physical location in the parquet corpus. This enables fast random
#' access to specific records without scanning entire partitions.
#'
#' The function is memory-efficient and can handle 300M+ records by using
#' a two-stage approach: first indexing each parquet file individually
#' (bounded memory per file), then redistributing into hive-partitioned
#' output by `id_block`. This avoids loading the entire dataset at once.
#' Stage 1 is parallelized using [future.apply::future_lapply()] and
#' supports resuming if interrupted. On macOS, a `.metadata_never_index`
#' file is created in the output directory to prevent Spotlight from indexing
#' the parquet files.
#'
#' @param corpus_dir Path to the parquet corpus directory.
#' @param index_file Output path for the index parquet file.
#'   parquet files by `id_block`.
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
#'   \item{parquet_file}{Path to the parquet file in the corpus}
#'   \item{file_row_number}{Row number within the file (0-indexed)}
#' }
#'
#' The index is partitioned by `id_block` (computed as
#' `floor(numeric_id / 10000)`). This enables O(1) lookups by first
#' computing the ID block, then reading only that partition.
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
#'   index_file = "/Volumes/openalex/parquet/works_id_index.parquet",
#'   memory_limit = "20GB"
#' )
#' }
#'
#' @export
#' @md
build_corpus_index <- function(
  corpus_dir,
  index_file,
  memory_limit = NULL,
  workers = NULL
) {
  if (!dir.exists(corpus_dir)) {
    stop("corpus_dir does not exist: ", corpus_dir)
  }

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
    DBI::dbDisconnect(con, shutdown = TRUE)
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
  ##   Stage 2: Redistribute into hive-partitioned output by id_block

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

      stage1_query <- paste0(
        "COPY (",
        "SELECT ",
        "  id, ",
        "  CAST(FLOOR(CAST(regexp_extract(id, '(\\d+)$', 1) AS BIGINT) / 10000) AS INTEGER) ",
        "    AS id_block, ",
        "  filename AS parquet_file, ",
        "  file_row_number ",
        "FROM read_parquet('",
        pf,
        "', filename = true, file_row_number = true)",
        ") TO '",
        out_file,
        "' (FORMAT PARQUET, COMPRESSION SNAPPY)"
      )
      DBI::dbExecute(conn = worker_con, stage1_query)
      p()
      invisible(NULL)
    })
  })

  message("    Stage 1 complete.")

  message("Stage 2: Combining into single index file ", index_file)

  arrow::open_dataset(temp_dir) |>
    arrow::write_parquet(index_file, compression = "snappy")

  unlink(temp_dir, recursive = TRUE)

  ## Stage 2: Write hive-partitioned index by id_block
  # message("Stage 2: Writing hive-partitioned index by id_block...")
  # dir.create(index_dir, recursive = TRUE, showWarnings = FALSE)
  # file.create(file.path(index_dir, ".metadata_never_index"))

  # copy_query <- paste0(
  #   "COPY (",
  #   "SELECT * FROM read_parquet('",
  #   temp_dir,
  #   "/idx_*.parquet')",
  #   ") TO '",
  #   index_dir,
  #   "' (FORMAT PARQUET, PARTITION_BY (id_block), COMPRESSION SNAPPY, ",
  #   "OVERWRITE_OR_IGNORE)"
  # )

  # message("    Executing index query (streaming to file)...")
  # DBI::dbExecute(conn = con, copy_query)

  # ## Clean up temp directory
  # if (dir.exists(paste0(index_dir, "_tmp"))) {
  #   message("    Cleaning up temp directory...")
  #   unlink(paste0(index_dir, "_tmp"), recursive = TRUE)
  # }

  # ## Get row count for reporting
  # count_query <- paste0(
  #   "SELECT COUNT(*) as n FROM read_parquet('",
  #   index_dir,
  #   "/**/*.parquet')"
  # )
  # row_count <- DBI::dbGetQuery(conn = con, count_query)$n

  # message(
  #   "Index built: ",
  #   format(row_count, big.mark = ","),
  #   " rows"
  # )

  ## Report size
  # index_files <- list.files(
  #   index_dir,
  #   pattern = "\\.parquet$",
  #   recursive = TRUE,
  #   full.names = TRUE
  # )
  index_files <- index_file
  total_size <- sum(file.info(index_files)$size)
  file_size_gb <- round(total_size / 1024^3, 2)
  # message(
  #   "Done! Index size: ",
  #   file_size_gb,
  #   " GB across ",
  #   length(index_files),
  #   " partition files"
  # )
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
