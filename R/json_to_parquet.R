#' Convert JSON files to Apache Parquet files
#'
#' The function takes a directory of JSON files as written from a call to `oa_request(..., json_dir = "FOLDER")`
#'  and converts it to a Apache Parquet dataset.
#'
#' @param json_dir The directory of JSON files returned from `oa_request(..., json_dir = "FOLDER")`.
#' @param parquet_dataset parquet dataset.
#' @param partition The column which should be used to partition the table. Hive partitioning is used.
#'   Set to NULL to not partition the table.
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
#' @md
#'
#' @examples
#' json_to_parquet(json_dir = "data/json", parquet_dataset = "data/arrow")
#'
#' @export
json_to_parquet <- function(
    json_dir = file.path("data", "json"),
    parquet_dataset = file.path("data", "data"),
    partition = NULL) {
  ## Define set of json files

  ## Create in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  ## Install and load jsonq
  paste0(
    "INSTALL json"
  ) |>
    DBI::dbExecute(conn = con)

  paste0(
    "LOAD json"
  ) |>
    DBI::dbExecute(conn = con)

  paste0(
    "COPY ( ",
    "   SELECT ",
    "       UNNEST(results,  max_depth := 2) ",
    "   FROM ",
    "       read_ndjson('", json_dir, "/*.json')",
    ") TO '", parquet_dataset, "' ",
    "(FORMAT PARQUET, COMPRESSION SNAPPY",
    ifelse(
      is.null(partition),
      ")",
      ", PARTITION_BY 'publication_year')"
    )
  ) |>
    DBI::dbExecute(conn = con)

  return(normalizePath(parquet_dataset))
}
