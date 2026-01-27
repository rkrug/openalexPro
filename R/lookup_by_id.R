#' Look up records by ID or DOI using a pre-built index
#'
#' This function retrieves specific records from a parquet corpus using
#' a Feather index built by [build_corpus_index()]. It reads only the
#' necessary files and rows, making it much faster than scanning the
#' entire corpus.
#'
#' @param index_file Path to the Feather index file, or a pre-loaded index
#'   data frame.
#' @param ids Character vector of OpenAlex IDs to look up (e.g.,
#'   "https://openalex.org/W2741809807" or "W2741809807").
#' @param dois Character vector of DOIs to look up (alternative to `ids`).
#' @param corpus_dir Path to the parquet corpus. If `NULL`, uses the directory
#'   containing the parquet files referenced in the index.
#'
#' @return A data frame containing the matching records from the corpus.
#'
#' @details
#' Either `ids` or `dois` must be provided (not both).
#'
#' IDs can be provided in either long form ("https://openalex.org/W2741809807")
#' or short form ("W2741809807"). The function will normalize them.
#'
#' The function uses DuckDB to efficiently read only the specific rows needed
#' from each parquet file, avoiding full file scans.
#'
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery
#' @importFrom duckdb duckdb
#' @importFrom arrow read_feather
#'
#' @examples
#' \dontrun{
#' # Look up by OpenAlex ID
#' records <- lookup_by_id(
#'   index_file = "works_index.feather",
#'   ids = c("W2741809807", "W1234567890")
#' )
#'
#' # Look up by DOI
#' records <- lookup_by_id(
#'   index_file = "works_index.feather",
#'   dois = c("10.1000/test1", "10.1000/test2")
#' )
#' }
#'
#' @export
#' @md
lookup_by_id <- function(
  index_file,
  ids = NULL,
  dois = NULL,
  corpus_dir = NULL
) {
  ## Validate inputs
  if (is.null(ids) && is.null(dois)) {
    stop("Either 'ids' or 'dois' must be provided")
  }
  if (!is.null(ids) && !is.null(dois)) {
    stop("Provide either 'ids' or 'dois', not both")
  }

  ## Load index if needed
  if (is.character(index_file)) {
    if (!file.exists(index_file)) {
      stop("Index file not found: ", index_file)
    }
    index <- arrow::read_feather(index_file)
  } else if (is.data.frame(index_file)) {
    index <- index_file
  } else {
    stop("index_file must be a file path or a data frame")
  }

  ## Normalize IDs to long form
  if (!is.null(ids)) {
    ids <- ifelse(
      grepl("^https://openalex.org/", ids),
      ids,
      paste0("https://openalex.org/", ids)
    )
    matches <- index[index$id %in% ids, ]
  } else {
    ## Normalize DOIs (handle with/without https://doi.org/ prefix)
    dois <- ifelse(
      grepl("^https://doi.org/", dois),
      dois,
      paste0("https://doi.org/", dois)
    )
    matches <- index[index$doi %in% dois & !is.na(index$doi), ]
  }

  if (nrow(matches) == 0) {
    message("No matching records found in index")
    return(data.frame())
  }

  message("Found ", nrow(matches), " matching records in index")

  ## Group by parquet file
  files <- unique(matches$parquet_file)

  ## Connect to DuckDB
  con <- DBI::dbConnect(duckdb::duckdb(), read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  ## Read records from each file
  results <- lapply(files, function(pq_file) {
    file_matches <- matches[matches$parquet_file == pq_file, ]
    row_numbers <- file_matches$file_row_number

    ## Build query to read specific rows
    ## DuckDB's file_row_number is 0-indexed
    query <- paste0(
      "SELECT * FROM read_parquet('",
      pq_file,
      "', file_row_number = true) ",
      "WHERE file_row_number IN (",
      paste(row_numbers, collapse = ", "),
      ")"
    )

    tryCatch(
      DBI::dbGetQuery(con, query),
      error = function(e) {
        warning("Failed to read from ", pq_file, ": ", e$message)
        data.frame()
      }
    )
  })

  ## Combine results
  result <- do.call(rbind, results)

  ## Remove the file_row_number column we added for filtering
  if ("file_row_number" %in% names(result)) {
    result$file_row_number <- NULL
  }

  message("Retrieved ", nrow(result), " records")

  return(result)
}
