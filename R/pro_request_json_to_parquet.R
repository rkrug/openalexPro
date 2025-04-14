#' Convert JSON files to Apache Parquet files

#'
#' The function takes a directory of JSON files as written from a call to `pro_request(..., source_dir = "FOLDER")`
#' and converts it to a Apache Parquet dataset partitiond by the page.
#'
#' @param source_dir The directory of JSON files returned from `pro_request(..., json_dir = "FOLDER")`.
#' @param corpus parquet dataset; default: temporary directory.
#' @param verbose Logical indicating whether to show a verbose information. Defaults to `FALSE`
#' @return The function does not return anything, but it creates a directory with
#'   Apache Parquet files.
#'
#' @details The function uses DuckDB to read the JSON files and to create the
#'   Apache Parquet files. The function creates a DuckDB connection in memory and
#'   readsds the JSON files into DuckDB when needed. Then it creates a SQL query to convert the
#'   JSON files to Apache Parquet files and to copy the result to the specified
#'   directory.
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#'
#' @md
#'
#' @examples
#' \dontrun{
#' source_to_parquet(source_dir = "json", source_type = "snapshot", corpus = "arrow")
#' }
#' @export

pro_request_json_to_parquet <- function(
  source_dir = NULL,
  corpus = tempfile(fileext = ".corpus"),
  verbose = FALSE
) {
  ## Check if source_dir is specified
  if (is.null(source_dir)) {
    stop("No source_dir to convert from specified!")
  }

  if (file.exists(corpus)) {
    if (verbose) {
      message(
        "Deleting and recreating `",
        corpus,
        "` to avoid inconsistencies."
      )
    }
    if (dir.exists(corpus)) {
      unlink(corpus, recursive = TRUE)
    }
    dir.create(corpus, recursive = TRUE)
  }

  ## Define set of json files
  jsons <- list.files(
    source_dir,
    pattern = "*.json$",
    full.names = TRUE
  )

  ## Create in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  ## Setup VIEWS

  ### Create `results` view
  paste0(
    "INSTALL json; LOAD json; "
  ) |>
    DBI::dbExecute(conn = con)

  for (i in seq_along(jsons)) {
    fn <- jsons[i]
    if (verbose) {
      message("Converting ", i, " of ", length(jsons), " : ", fn)
    }

    pn <- basename(fn) |>
      gsub(pattern = ".json|page_", replacement = "")

    paste0(
      "COPY ( ",
      "SELECT ",
      pn,
      " AS page, UNNEST(results, max_depth := 2) ",
      "FROM read_json_auto('",
      fn,
      "' ) ",
      ") TO '",
      corpus,
      "' ",
      "(FORMAT PARQUET, COMPRESSION SNAPPY, APPEND, PARTITION_BY 'page');"
    ) |>
      DBI::dbExecute(conn = con)
  }

  return(normalizePath(corpus))
}
