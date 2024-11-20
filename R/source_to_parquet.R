#' Convert JSON files to Apache Parquet files
#'
#' The function takes a directory of JSON files as written from a call to `pro_request(..., source_dir = "FOLDER")`
#'  and converts it to a Apache Parquet dataset.
#'
#' @param source_dir The directory of JSON files returned from `pro_request(..., json_dir = "FOLDER")`.
#' @param source_type The type of source files. Possible  values are:
#'    - **pro_request**: The directory of JSON files returned from `pro_request(..., json_dir = "FOLDER")`
#'    - **snapshot**: The directory of the in parquet converted works in a snapshot.
#' @param corpus parquet dataset; default: temporary directory.
#' @param citations Logical. Indicating whether to include additional `citation` field
#'   (e.g. `Darwin & Newton (1903)`) in the works. Default: `FALSE` which means no `citation` field in
#' @param abstractes Logical. Indicating whether to extract abstract from inverted index into the field called `abstract`.
#'   Default: `FALSE` which means no additional `abstract` field
#' @param ids `data.frams` or `tibble` with `id` column which will be used to filter the works to be converted. Default: `NULL`, no filtering.
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
source_to_parquet <- function(
    source_dir = NULL,
    source_type = "pro_request",
    corpus = tempfile(fileext = ".corpus"),
    citations = FALSE,
    abstracts = FALSE,
    ids = NULL,
    verbose = FALSE) {
  ## Check if source_dir is specified
  if (is.null(source_dir)) {
    stop("No source_dir to convert from specified!")
  }

  ##
  if (citations & !abstracts) {
    from_view <- "results_with_citation"
  } else if (!citations & abstracts) {
    from_view <- "results_with_abstracts"
  } else if (citations & abstracts) {
    from_view <- "results_with_abstracts_citation"
  } else {
    from_view <- "results"
  }
  ##

  if (file.exists(corpus)) {
    if (verbose) {
      message("Deleting and recreating `", corpus, "` to avoid inconsistencies.")
    }
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

  ### Create `results` view
  switch(source_type,
    pro_request = {
      paste0(
        "INSTALL json; ",
        "LOAD json; ",
        " CREATE VIEW results AS SELECT UNNEST(results, max_depth := 2) FROM read_json_auto('", source_dir, "/*.json');"
      ) |>
        paste0(collapse = "\n") |>
        DBI::dbExecute(conn = con)
    },
    snapshot = {
      paste0(
        "CREATE VIEW results AS SELECT * FROM read_parquet('", source_dir, "/**/*.parquet');"
      ) |>
        paste0(collapse = "\n") |>
        DBI::dbExecute(conn = con)
    },
    stop("Unknown source_type! Unse `snapshot` or `pro_request`!")
  )


  ### create other needed vies based on results
  system.file("source_to_parquet.sql", package = "openalexPro") |>
    load_sql_file() |>
    DBI::dbExecute(conn = con)

  if (!is.null(ids)) {
    DBI::dbWriteTable(
      conn = con,
      name = "ids",
      value = ids |>
        dplyr::select(id)
    )
    paste0(
      "COPY ( ",
      "   SELECT ",
      "       SUBSTR(id, 23)::bigint // 10000  AS id_block, ",
      "       *  ",
      "   FROM ",
      "       ", from_view, " ",
      "   NATURAL JOIN ",
      "       ids",
      ") TO '", corpus, "' ",
      "(FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY 'id_block')"
    ) |>
      DBI::dbExecute(conn = con)
  } else {
    paste0(
      "COPY ( ",
      "   SELECT ",
      "       * ",
      "   FROM ",
      "       ", from_view, " ",
      ") TO '", corpus, "' ",
      "(FORMAT PARQUET, COMPRESSION SNAPPY",
      ifelse(
        is.null(partition),
        ")",
        paste0(", PARTITION_BY '", partition, "')")
      )
    ) |>
      DBI::dbExecute(conn = con)
  }

  return(normalizePath(corpus))
}
