#' Convert JSON files to Apache Parquet files
#'
#' The function takes a directory of JSON files as written from a call to `oa_request(..., json_dir = "FOLDER")`
#'  and converts it to a Apache Parquet dataset.
#'
#' @param json_dir The directory of JSON files returned from `oa_request(..., json_dir = "FOLDER")`.
#' @param corpus parquet dataset; default: temporary directory.
#' @param partition The column which should be used to partition the table. Hive partitioning is used.
#' @param delete_json If `TRUE` the `json_dir` directory will be deleted after conversion
#'
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
#' json_to_parquet(json_dir = "json", corpus = "arrow")
#' }
#' @export
json_to_parquet <- function(
    json_dir = NULL,
    corpus = tempfile(fileext = ".corpus"),
    partition = "publication_year",
    delete_json = FALSE) {
  ## Check if json_dir is specified
  if (is.null(json_dir)) {
    stop("No json_dir to convert from specified!")
  }

  if (file.exists(corpus)) {
    message("Deleting and recreating `", corpus, "` to avoid inconsistencies.")
    if (dir.exists(corpus)) {
      unlink(corpus, recursive = TRUE)
    }
    dir.create(corpus, recursive = TRUE)
  }


  ## Define set of json files

  ## Create in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  ## Setup VIEWS

  system.file("views_json.sql", package = "openalexPro") |>
    load_sql_file() |>
    gsub(pattern = "%%JSON_DIR%%", replacement = json_dir) |>
    DBI::dbExecute(conn = con)

  paste0(
    "COPY ( ",
    "   SELECT ",
    "       * ",
    "   FROM ",
    "       for_parquet",
    ") TO '", corpus, "' ",
    "(FORMAT PARQUET, COMPRESSION SNAPPY",
    ifelse(
      is.null(partition),
      ")",
      paste0(", PARTITION_BY '", partition, "')")
    )
  ) |>
    DBI::dbExecute(conn = con)

  ##
  if (delete_json) {
    unlink(json_dir, recursive = TRUE)
  }
  ##
  return(normalizePath(corpus))
}
