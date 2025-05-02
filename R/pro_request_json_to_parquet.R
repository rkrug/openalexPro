#' Convert JSON files to Apache Parquet files

#'
#' The function takes a directory of JSON files as written from a call to `pro_request(..., json_dir = "FOLDER")`
#' and converts it to a Apache Parquet dataset partitiond by the page.
#'
#' @param json_dir The directory of JSON files returned from `pro_request(..., json_dir = "FOLDER")`.
#' @param corpus parquet dataset; default: temporary directory.
#' @param verbose Logical indicating whether to show a verbose information. Defaults to `TRUE`
#' @param normalize_schemata Determines if the schemata should be normalized, i.e. If not,
#'   certain fields might not work, but for some app;licatons this is faster. Defasults to `FALSE`
#' @param ROW_GROUP_SIZE Only used when `normalize_schemata = TRUE`. Maximum number of rows per row group. Smaller sizes reduce memory
#'   usage, larger sizes improve compression. Defaults to `10000`.
#'   See: \url{https://duckdb.org/docs/sql/statements/copy#row_group_size}
#' @param ROW_GROUPS_PER_FILE Only used when `normalize_schemata = TRUE`. Number of row groups to include in each output Parquet file.
#'   Controls file size and write frequency. Defaults to `1`
#'   See: \url{https://duckdb.org/docs/sql/statements/copy#row_groups_per_file}
#' @param enrich_corpus Determines if the function `enrich_parquets()` should be run. Defatults to `FALSE`
#' @param delete_input Determines if the `json_dir` should be deleted afterwards. Defaults to `FALSE`.
#' @return The function does not returns the directory with the corpus.
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
#' source_to_parquet(json_dir = "json", source_type = "snapshot", corpus = "arrow")
#' }
#' @export

pro_request_json_to_parquet <- function(
  json_dir = NULL,
  corpus = tempfile(fileext = "_corpus"),
  overwrite = FALSE,
  verbose = TRUE,
  delete_input = FALSE
) {
  ## Check if json_dir is specified
  if (is.null(json_dir)) {
    stop("No json_dir to convert from specified!")
  }

  ## Check if corpus is specified
  if (is.null(corpus)) {
    stop("No corpus to convert to specified!")
  }
  if (file.exists(corpus)) {
    if (!(overwrite)) {
      stop(
        "corpus ",
        corpus,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    } else {
      unlink(corpus, recursive = TRUE, force = TRUE)
    }
  }

  ## Read names of json files
  jsons <- list.files(
    json_dir,
    pattern = "*.json$",
    full.names = TRUE
  )

  types <- jsons |>
    basename() |>
    strsplit(split = "_") |>
    sapply(FUN = '[[', 1) |>
    unique()

  if (length(types) > 1) {
    stop("All JSON files must be of the same type!")
  }

  if (types == "group") {
    types <- "group_by"
  }

  ## Create in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    }
  )

  ## Setup VIEWS

  ### Create `results` view
  paste0(
    "INSTALL json; LOAD json; "
  ) |>
    DBI::dbExecute(conn = con)

  # pb <- txtProgressBar(min = 0, max = length(jsons), style = 3) # style 3 = nice bar

  for (i in seq_along(jsons)) {
    fn <- jsons[i]
    if (verbose) {
      message("Converting ", i, " of ", length(jsons), " : ", fn)
    }

    pn <- basename(fn) |>
      strsplit(split = "_")

    pn <- pn[[1]][length(pn[[1]])] |>
      gsub(pattern = ".json", replacement = "")

    try(
      {
        paste0(
          "COPY ( ",
          "SELECT ",
          pn,
          " AS page, ",
          "UNNEST(",
          types,
          ", max_depth := 2) ",
          "FROM read_json_auto('",
          fn,
          "' ) ",
          ") TO '",
          corpus,
          "' ",
          "(FORMAT PARQUET, COMPRESSION SNAPPY, APPEND, PARTITION_BY 'page');"
        ) |>
          DBI::dbExecute(conn = con)
        if (verbose) {
          message("   Done")
        }
      },
      silent = !verbose
    )

    # setTxtProgressBar(pb, i)
  }

  if (delete_input) {
    unlink(json_dir, recursive = TRUE, force = TRUE)
  }

  return(normalizePath(corpus))
}
