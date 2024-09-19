#' Convert JSON files to a tibble
#'
#' The function takes a directory of JSON files as written from a call to
#' `json_to_parquet(..., json_dir = "FOLDER")` and converts it to a tibble.
#'
#' @param json_dir The directory of JSON files returned from `json_to_parquet(..., json_dir = "FOLDER")`.
#'
#' @return The tibble of the JSON files.
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
#' json_to_tibble(json_dir = "data/json")
#'
#' @export
json_to_tibble <- function(
    json_dir = file.path("data", "json")) {
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

  result <- paste0(
    "   SELECT ",
    "       UNNEST(results,  max_depth := 2) ",
    "   FROM ",
    "       read_ndjson('", json_dir, "/*.json', maximum_object_size=1000000000)"
  ) |>
    DBI::dbGetQuery(conn = con) |>
    tibble::as_tibble()

  return(result)
}
