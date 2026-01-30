#' Look up records by ID using a pre-built index
#'
#' This function retrieves specific records from a parquet corpus using
#' an index built by [build_corpus_index()]. It reads only the
#' necessary files and rows, making it much faster than scanning the
#' entire corpus.
#'
#' @param index_file Path to the index parquet file created by
#'   [build_corpus_index()].
#' @param ids Character vector of OpenAlex IDs to look up. Can be in long form
#'   (e.g., `"https://openalex.org/W2741809807"`) or short form
#'   (e.g., `"W2741809807"`).
#' @param workers Number of parallel workers for reading corpus files.
#'   Default is `NULL` (sequential). If `> 1`, uses
#'   [future.apply::future_lapply()] with [future::multisession].
#' @param selected Path to the parquet dataset containing the selected indices,
#'   partitioned by `parquet_file` of the work. If `NULL`, not saved.
#' @param output Path to an output directory for writing results as parquet
#'   files. If `NULL` (default), results are returned as a data frame.
#'   If set, filtered records are written directly to parquet (one file per
#'   source corpus file) without loading them into R memory. The directory
#'   must not already exist.
#' @param verbose If `TRUE`, print progress messages. Default: `TRUE`
#'
#' @return If `output` is `NULL`, a data frame containing the matching records.
#'   If `output` is set, the output directory path is returned invisibly.
#'
#' @details
#' The function first filters the index (a single parquet file) using
#' [arrow::open_dataset()] and [dplyr::filter()] to find matching IDs.
#' It then uses DuckDB to efficiently read only the specific rows needed
#' from each corpus parquet file, avoiding full file scans.
#'
#' When `output` is set, DuckDB writes the filtered rows directly to parquet
#' files using `COPY ... TO`, so the data never enters R memory. This is
#' essential for lookups involving millions of IDs.
#'
#' @importFrom arrow open_dataset write_dataset
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery dbExecute
#' @importFrom dplyr filter collect
#' @importFrom duckdb duckdb
#' @importFrom future plan multisession
#' @importFrom future.apply future_lapply
#' @importFrom progressr with_progress progressor
#'
#' @examples
#' \dontrun{
#' # Return results as data frame
#' records <- lookup_by_id(
#'   index_file = "works_id_index.parquet",
#'   ids = c("W2741809807", "W1234567890")
#' )
#'
#' # Write results to parquet (for millions of IDs)
#' lookup_by_id(
#'   index_file = "works_id_index.parquet",
#'   ids = large_id_vector,
#'   output = "filtered_works",
#'   workers = 3
#' )
#' }
#'
#' @export
#' @md
lookup_by_id <- function(
  index_file,
  ids,
  selected = NULL,
  workers = NULL,
  output = NULL,
  verbose = TRUE
) {
  ## Validate inputs
  if (missing(ids) || length(ids) == 0) {
    stop("'ids' must be provided")
  }

  ## Check index exists
  index_file <- normalizePath(index_file, mustWork = FALSE)
  snapshot_path <- dirname(index_file)
  if (!file.exists(index_file)) {
    stop("Index file not found: ", index_file)
  }

  ## Validate output directory
  if (!is.null(output)) {
    if (dir.exists(output)) {
      stop("Output directory already exists: ", output)
    }
  }

  ## Normalize IDs - add prefix if missing
  if (verbose) {
    message("Normalizing ids to long form ...")
  }
  ids <- ifelse(
    grepl("^https://openalex.org/", ids),
    ids,
    paste0("https://openalex.org/", ids)
  )

  ## Connect to DuckDB for index queries
  # con <- DBI::dbConnect(duckdb::duckdb(), read_only = TRUE)
  # on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  ## Compute id_blocks and group IDs by block
  # blocks <- id_block(ids)
  # id_chunks <- split(ids, blocks)

  if (verbose) {
    message(
      "Looking up ",
      length(ids),
      " ..."
    )
  }

  ## Query each id_block partition separately
  matches <- index_file |>
    arrow::open_dataset() |>
    dplyr::filter(id %in% ids) |>
    dplyr::collect()

  if (is.null(matches) || nrow(matches) == 0) {
    message("No matching records found in index")
    if (!is.null(output)) {
      return(invisible(output))
    }
    return(data.frame())
  }

  if (verbose) {
    message("Found ", nrow(matches), " matching records in index")
  }

  if (!is.null(selected)) {
    if (verbose) {
      message(
        "Saving selected ids to ",
        selected
      )
    }
    arrow::write_dataset(
      dataset = matches,
      path = selected,
      format = "parquet",
      partitioning = "parquet_file"
    )
  }

  ## Set up parallel plan if workers > 1
  if (!is.null(workers) && workers > 1) {
    old_plan <- future::plan(future::multisession, workers = workers)
    on.exit(future::plan(old_plan), add = TRUE)
  }

  ## Split matches by corpus file
  if (verbose) {
    message("Splitting into parquet files ...")
  }
  file_chunks <- split(matches$file_row_number, matches$parquet_file)
  names(file_chunks) <- file.path(snapshot_path, names(file_chunks))

  ## Read/write records from each corpus file (parallel if workers > 1)
  if (verbose) {
    message("Retrieving and saving works per parquet file ...")
  }

  ##### this is waiting for rewrite - stopgap solution!
  oopts <- options(future.globals.maxSize = 1.0 * 1e9) ## 1.0 GB
  on.exit(options(oopts), add = TRUE)
  #####

  if (!is.null(output)) {
    dir.create(output, recursive = TRUE, showWarnings = FALSE)
  }

  progressr::with_progress({
    p <- progressr::progressor(along = file_chunks)
    results <- future.apply::future_lapply(
      names(file_chunks),
      function(pq_file) {
        row_numbers <- file_chunks[[pq_file]]

        ## Each worker gets its own DuckDB connection
        worker_con <- DBI::dbConnect(duckdb::duckdb(), read_only = TRUE)
        on.exit(DBI::dbDisconnect(worker_con, shutdown = TRUE))

        row_filter <- paste(row_numbers, collapse = ", ")

        result <- if (!is.null(output)) {
          ## Write directly to parquet — never loads into R memory
          out_file <- file.path(output, paste0("part_", basename(pq_file)))
          copy_query <- paste0(
            "COPY (SELECT * FROM read_parquet('",
            pq_file,
            "', file_row_number = true) ",
            "WHERE file_row_number IN (",
            row_filter,
            ")) ",
            "TO '",
            out_file,
            "' (FORMAT PARQUET, COMPRESSION SNAPPY)"
          )
          tryCatch(
            {
              DBI::dbExecute(worker_con, copy_query)
              length(row_numbers)
            },
            error = function(e) {
              warning("Failed to write from ", pq_file, ": ", e$message)
              0L
            }
          )
        } else {
          ## Return data frame (in-memory mode)
          query <- paste0(
            "SELECT * FROM read_parquet('",
            pq_file,
            "', file_row_number = true) ",
            "WHERE file_row_number IN (",
            row_filter,
            ")"
          )
          tryCatch(
            DBI::dbGetQuery(worker_con, query),
            error = function(e) {
              warning("Failed to read from ", pq_file, ": ", e$message)
              data.frame()
            }
          )
        }

        p()
        result
      }
    )
  }, handlers = progressr::handler_cli())

  if (!is.null(output)) {
    total <- sum(unlist(results))
    message("Written ", total, " records to ", output)
    return(invisible(output))
  }

  ## Combine results (in-memory mode)
  result <- do.call(rbind, results)

  ## Remove the file_row_number column we added for filtering
  if ("file_row_number" %in% names(result)) {
    result$file_row_number <- NULL
  }

  message("Retrieved ", nrow(result), " records")

  return(result)
}
