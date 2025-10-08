#' Convert JSON files to Apache Parquet files
#'
#'
#' The function takes a directory of JSON files as written from a call to
#' `pro_request(..., json_dir = "FOLDER")` and converts it to a Apache Parquet
#' dataset partitiond by the page.
#'
#' @param input_jsonl The directory of JSON files returned from
#'   `pro_request(..., json_dir = "FOLDER")`.
#' @param output output directory for the parquet dataset; default: temporary
#'   directory.
#' @param add_columns List of additional fields to be added to the output. They
#'   nave to be provided as a named list, e./g. `list(column_1 = "value_1",
#'   column_2 = 2)`. Only Scalar values are supported.
#' @param overwrite Logical indicating whether to overwrite `output`.
#' @param verbose Logical indicating whether to show a verbose information.
#'   Defaults to `TRUE`
#' @param delete_input Determines if the `input_jsonl` should be deleted
#'   afterwards. Defaults to `FALSE`.
#'
#' @return The function does returns the output invisibly.
#'
#' @details The function uses DuckDB to read the JSON files and to create the
#'   Apache Parquet files. The function creates a DuckDB connection in memory
#'   and readsds the JSON files into DuckDB when needed. Then it creates a SQL
#'   query to convert the JSON files to Apache Parquet files and to copy the
#'   result to the specified directory.
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#'
#' @md
#'
#' @export

pro_request_jsonl_parquet <- function(
  input_jsonl = NULL,
  output = NULL,
  add_columns = list(),
  overwrite = FALSE,
  verbose = TRUE,
  delete_input = FALSE
) {
  # Argument Checks --------------------------------------------------------

  ## Check if input_jsonl is specified
  if (is.null(input_jsonl)) {
    stop("No `input_jsonl` to convert specified!")
  }

  ## Check if output is specified
  if (is.null(output)) {
    stop("No output to convert to specified!")
  }

  # Preparations -----------------------------------------------------------

  ## Create and setup in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE),
    add = TRUE
  )
  paste0(
    "INSTALL json; LOAD json; "
  ) |>
    DBI::dbExecute(conn = con)

  if (file.exists(output)) {
    if (!(overwrite)) {
      stop(
        "output ",
        output,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    } else {
      unlink(
        output,
        recursive = TRUE,
        force = TRUE
      )
    }
  } else {
    dir.create(
      output,
      recursive = TRUE,
      showWarnings = FALSE
    )
  }

  ## Read names of json files
  jsons <- list.files(
    input_jsonl,
    pattern = "*.json$",
    full.names = TRUE,
    recursive = TRUE
  )

  jsons <- jsons[
    order(
      as.numeric(
        sub(
          ".*_([0-9]+)\\.json$",
          "\\1",
          jsons
        )
      )
    )
  ]

  types <- jsons |>
    basename() |>
    strsplit(split = "_") |>
    vapply(
      FUN = '[[',
      1,
      FUN.VALUE = character(1)
    ) |>
    unique()

  if (length(types) > 1) {
    stop("All JSON files must be of the same type!")
  }

  if (types == "group") {
    types <- "group_by"
  }

  if (types == "single") {}

  # Go through all jsons, i.e. one per page --------------------------------
  ### Names: results_page_x.json
  for (i in seq_along(jsons)) {
    fn <- jsons[i]
    if (verbose) {
      message("Converting ", i, " of ", length(jsons), " : ", fn)
    }

    try(
      {
        ## save as page partitioned parquet
        sprintf(
          "
              COPY (
                SELECT
                  *
                FROM 
                  read_json_auto( '%s' )
              ) TO
                '%s'
              (FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY 'page', APPEND)
          ",
          fn,
          output
        ) |>
          DBI::dbExecute(conn = con)
        if (verbose) {
          message("   Done")
        }
      },
      silent = !verbose
    )
  }

  if (delete_input) {
    unlink(input_jsonl, recursive = TRUE, force = TRUE)
  }

  return(invisible(normalizePath(output)))
}
