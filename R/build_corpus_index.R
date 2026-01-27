#' Build a Feather index for fast ID lookups in a parquet corpus
#'
#' This function creates a Feather index file that maps OpenAlex IDs (and DOIs)
#' to their physical location in the parquet corpus. This enables fast random
#' access to specific records without scanning entire partitions.
#'
#' @param corpus_dir Path to the parquet corpus directory.
#' @param index_file Output path for the Feather index file.
#' @param memory_limit DuckDB memory limit (e.g., "20GB"). Default is `NULL`.
#' @param threads Number of DuckDB threads. Default is `NULL` (use all cores).
#'
#' @return Invisibly returns the path to the created index file.
#'
#' @details
#' The index contains the following columns:
#' \describe{
#'   \item{id}{OpenAlex work ID (e.g., "https://openalex.org/W2741809807")}
#'   \item{doi}{DOI (nullable, for secondary lookup)}
#'   \item{parquet_file}{Path to the parquet file}
#'   \item{file_row_number}{Row number within the file (0-indexed)}
#' }
#'
#' The index is stored in Feather (Arrow IPC) format for fast memory-mapped access.
#'
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery dbExecute
#' @importFrom duckdb duckdb
#' @importFrom arrow write_feather
#'
#' @examples
#' \dontrun{
#' # Build index for works corpus
#' build_corpus_index(
#'   corpus_dir = "/Volumes/openalex/arrow/works",
#'   index_file = "/Volumes/openalex/arrow/works_index.feather",
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
  threads = NULL
) {
  if (!dir.exists(corpus_dir)) {
    stop("corpus_dir does not exist: ", corpus_dir)
  }

  index_dir <- dirname(index_file)
  if (!dir.exists(index_dir)) {
    dir.create(index_dir, recursive = TRUE)
  }

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
  if (!is.null(threads)) {
    DBI::dbExecute(
      conn = con,
      paste0("SET threads = ", threads)
    )
  }

  message("Building index from: ", corpus_dir)
  message("This will scan all parquet files (id and doi columns only)...")

  total_start <- Sys.time()

  ## Build index query - reads only id and doi columns, extracts physical location
  query <- paste0(
    "SELECT ",
    "  id, ",
    "  doi, ",
    "  filename AS parquet_file, ",
    "  file_row_number ",
    "FROM read_parquet('",
    corpus_dir,
    "/**/*.parquet', filename = true, file_row_number = true)"
  )

  message("Executing index query...")
  index_data <- DBI::dbGetQuery(conn = con, query)

  message(
    "Index built: ",
    format(nrow(index_data), big.mark = ","),
    " rows"
  )

  ## Write to Feather format
  message("Writing index to: ", index_file)
  arrow::write_feather(index_data, index_file)

  file_size_gb <- round(file.info(index_file)$size / 1024^3, 2)
  message(
    "Done! Index file size: ",
    file_size_gb,
    " GB"
  )
  message(
    "Total time: ",
    round(difftime(Sys.time(), total_start, units = "mins"), 2),
    " minutes"
  )

  invisible(index_file)
}
