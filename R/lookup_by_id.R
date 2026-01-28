#' Look up records by ID using a pre-built index
#'
#' This function retrieves specific records from a parquet corpus using
#' an index built by [build_corpus_index()]. It reads only the
#' necessary files and rows, making it much faster than scanning the
#' entire corpus.
#'
#' @param index_dir Path to the index. For OpenAlex ID indexes
#'   (`id_column = "id"`), this is the partitioned index directory.
#'   For DOI indexes (`id_column = "doi"`), this is the single parquet file.
#' @param ids Character vector of IDs to look up.
#' @param id_column The type of ID column that was indexed. This determines
#'   how IDs are normalized and how the index is queried:
#'   \describe{
#'     \item{`"id"`}{OpenAlex IDs - uses partitioned index with id_block for
#'       O(1) lookups. Adds "https://openalex.org/" prefix if missing.}
#'     \item{`"doi"`}{DOIs - uses single-file index. Adds "https://doi.org/"
#'       prefix if missing.}
#'   }
#'   Must match the `id_column` used when building the index.
#'
#' @return A data frame containing the matching records from the corpus.
#'
#' @details
#' The function uses DuckDB to efficiently read only the specific rows needed
#' from each parquet file, avoiding full file scans.
#'
#' For OpenAlex IDs (`id_column = "id"`), the lookup is O(1) because:
#' 1. The id_block is computed from each ID
#' 2. Only the relevant partition(s) are read from the index
#' 3. The specific rows are fetched from the corpus
#'
#' For DOIs (`id_column = "doi"`), the entire index must be scanned since
#' DOIs have no predictable structure for partitioning.
#'
#' You can provide IDs in either long form (with URL prefix) or short form.
#'
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery
#' @importFrom duckdb duckdb
#' @importFrom arrow read_parquet
#'
#' @examples
#' \dontrun{
#' # Look up by OpenAlex ID (using partitioned index - fast O(1))
#' records <- lookup_by_id(
#'   index_dir = "works_id_index",
#'   ids = c("W2741809807", "W1234567890"),
#'   id_column = "id"
#' )
#'
#' # Look up by DOI (using single-file index)
#' records <- lookup_by_id(
#'   index_dir = "works_doi_index.parquet",
#'   ids = c("10.1000/test1", "10.1000/test2"),
#'   id_column = "doi"
#' )
#' }
#'
#' @export
#' @md
lookup_by_id <- function(
  index_dir,
  ids,
  id_column = "id"
) {
  ## Validate inputs
  if (missing(ids) || length(ids) == 0) {
    stop("'ids' must be provided")
  }

  if (!id_column %in% c("id", "doi")) {
    stop("id_column must be 'id' or 'doi'")
  }

  ## Check index exists
  if (id_column == "id") {
    if (!dir.exists(index_dir)) {
      stop("Index directory not found: ", index_dir)
    }
  } else {
    if (!file.exists(index_dir)) {
      stop("Index file not found: ", index_dir)
    }
  }

  ## Normalize IDs based on id_column type
  if (id_column == "id") {
    ids <- ifelse(
      grepl("^https://openalex.org/", ids),
      ids,
      paste0("https://openalex.org/", ids)
    )
  } else {
    ids <- ifelse(
      grepl("^https://doi.org/", ids),
      ids,
      paste0("https://doi.org/", ids)
    )
  }

  ## Connect to DuckDB
  con <- DBI::dbConnect(duckdb::duckdb(), read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  ## Query index based on id_column type
  if (id_column == "id") {
    ## For OpenAlex IDs: use partitioned index with id_block filtering
    ## Compute id_blocks for the requested IDs
    id_blocks <- id_block(ids)
    unique_blocks <- unique(id_blocks)

    message(
      "Looking up ", length(ids), " IDs across ",
      length(unique_blocks), " partition(s)..."
    )

    ## Build query that filters by id_block (partition pruning)
    ## DuckDB will only read the relevant partitions
    ids_escaped <- gsub("'", "''", ids)
    ids_sql <- paste0("'", ids_escaped, "'", collapse = ", ")

    index_query <- paste0(
      "SELECT id, parquet_file, file_row_number ",
      "FROM read_parquet('", index_dir, "/**/*.parquet', ",
      "hive_partitioning = true) ",
      "WHERE id_block IN (", paste(unique_blocks, collapse = ", "), ") ",
      "AND id IN (", ids_sql, ")"
    )

    matches <- DBI::dbGetQuery(con, index_query)
  } else {
    ## For DOIs: query single file index
    message("Looking up ", length(ids), " DOIs in index...")

    ids_escaped <- gsub("'", "''", ids)
    ids_sql <- paste0("'", ids_escaped, "'", collapse = ", ")

    index_query <- paste0(
      "SELECT id, parquet_file, file_row_number ",
      "FROM read_parquet('", index_dir, "') ",
      "WHERE id IN (", ids_sql, ")"
    )

    matches <- DBI::dbGetQuery(con, index_query)
  }

  if (nrow(matches) == 0) {
    message("No matching records found in index")
    return(data.frame())
  }

  message("Found ", nrow(matches), " matching records in index")

  ## Group by parquet file
  files <- unique(matches$parquet_file)

  ## Read records from each corpus file
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
