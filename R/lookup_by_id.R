#' Look up records by ID using a pre-built index
#'
#' This function retrieves specific records from a parquet corpus using
#' an index built by [build_corpus_index()]. It reads only the
#' necessary files and rows, making it much faster than scanning the
#' entire corpus.
#'
#' @param index_file Path to the partitioned index file created by
#'   [build_corpus_index()].
#' @param ids Character vector of OpenAlex IDs to look up. Can be in long form
#'   (e.g., `"https://openalex.org/W2741809807"`) or short form
#'   (e.g., `"W2741809807"`).
#' @param workers Number of parallel workers for reading corpus files.
#'   Default is `NULL` (sequential). If `> 1`, uses
#'   [future.apply::future_lapply()] with [future::multisession].
#' @param output Path to an output directory for writing results as parquet
#'   files. If `NULL` (default), results are returned as a data frame.
#'   If set, filtered records are written directly to parquet (one file per
#'   source corpus file) without loading them into R memory. The directory
#'   must not already exist.
#'
#' @return If `output` is `NULL`, a data frame containing the matching records.
#'   If `output` is set, the output directory path is returned invisibly.
#'
#' @details
#' The function uses DuckDB to efficiently read only the specific rows needed
#' from each parquet file, avoiding full file scans.
#'
#' The lookup is O(1) because:
#' 1. The id_block is computed from each ID
#' 2. Only the relevant partition(s) are read from the index
#' 3. The specific rows are fetched from the corpus
#'
#' When `output` is set, DuckDB writes the filtered rows directly to parquet
#' files using `COPY ... TO`, so the data never enters R memory. This is
#' essential for lookups involving millions of IDs.
#'
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery dbExecute
#' @importFrom duckdb duckdb
#' @importFrom future plan multisession
#' @importFrom future.apply future_lapply
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
  workers = NULL,
  output = NULL
) {
  ## Validate inputs
  if (missing(ids) || length(ids) == 0) {
    stop("'ids' must be provided")
  }

  ## Check index exists
  if (!file.exists(index_file)) {
    stop("Index file not found: ", index_file)
  }

  ## Validate output directory
  if (!is.null(output)) {
    if (dir.exists(output)) {
      stop("Output directory already exists: ", output)
    }
    dir.create(output, recursive = TRUE, showWarnings = FALSE)
  }

  ## Normalize IDs - add prefix if missing
  ids <- ifelse(
    grepl("^https://openalex.org/", ids),
    ids,
    paste0("https://openalex.org/", ids)
  )

  ## Connect to DuckDB for index queries
  con <- DBI::dbConnect(duckdb::duckdb(), read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  ## Compute id_blocks and group IDs by block
  blocks <- id_block(ids)
  id_chunks <- split(ids, blocks)

  message(
    "Looking up ",
    length(ids),
    " IDs across ",
    length(id_chunks),
    " partition(s)..."
  )

  ## Query each id_block partition separately
  matches <- do.call(
    rbind,
    lapply(names(id_chunks), function(block) {
      chunk_ids <- id_chunks[[block]]
      ids_escaped <- gsub("'", "''", chunk_ids)
      ids_sql <- paste0("'", ids_escaped, "'", collapse = ", ")

      index_query <- paste0(
        "SELECT id, parquet_file, file_row_number ",
        "FROM read_parquet('",
        index_file,
        "') ",
        "WHERE id_block = ",
        block,
        " ",
        "AND id IN (",
        ids_sql,
        ")"
      )

      DBI::dbGetQuery(con, index_query)
    })
  )

  if (is.null(matches) || nrow(matches) == 0) {
    message("No matching records found in index")
    if (!is.null(output)) {
      return(invisible(output))
    }
    return(data.frame())
  }

  message("Found ", nrow(matches), " matching records in index")

  ## Set up parallel plan if workers > 1
  if (!is.null(workers) && workers > 1) {
    old_plan <- future::plan(future::multisession, workers = workers)
    on.exit(future::plan(old_plan), add = TRUE)
  }

  ## Split matches by corpus file
  file_chunks <- split(matches$file_row_number, matches$parquet_file)

  ## Read/write records from each corpus file (parallel if workers > 1)
  results <- future.apply::future_lapply(names(file_chunks), function(pq_file) {
    row_numbers <- file_chunks[[pq_file]]

    ## Each worker gets its own DuckDB connection
    worker_con <- DBI::dbConnect(duckdb::duckdb(), read_only = TRUE)
    on.exit(DBI::dbDisconnect(worker_con, shutdown = TRUE))

    row_filter <- paste(row_numbers, collapse = ", ")

    if (!is.null(output)) {
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
  })

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
