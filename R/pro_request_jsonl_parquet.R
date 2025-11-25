#' Convert JSON files to Apache Parquet files
#'
#'
#' The function takes a directory of JSONL files as written from a call to
#' `pro_request_jsonl(...)` and converts it to a Apache Parquet files. Each
#' jsonl is processed individually, so there is no limit of the number of records.
#'
#' The value `page` as created in `pro_request_jsonl()` is used for partitioning.
#' All jsonl files are combined into a single Apache Parquet dataset, but can be
#' filtered out by using the "page". As an example:
#'
#' 1. the subfolder in the `output` folder is called `Chunk_1`
#' 2. the page othe json file represents is `2`
#' 3. The resulting values for `page` will be `Chunk_1_2`
#'
#'
#' @param input_jsonl The directory of JSON files returned from
#'   `pro_request(..., json_dir = "FOLDER")`.
#' @param output output directory for the parquet dataset; default: temporary
#'   directory.
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

  # Instead to unify schematas - suggested  by chatGPT:

  # library(DBI)
  # library(duckdb)

  # con <- dbConnect(duckdb())

  # json_dir <- "path/to/jsonl" # adjust
  # output <- "path/to/out.parquet" # your original output
  # json_glob <- file.path(json_dir, "*.jsonl")

  # json_files <- list.files(
  #   json_dir,
  #   pattern = "\\.jsonl$",
  #   full.names = TRUE
  # )

  # ## 1) Global schema inference (no data materialized in R)

  # schema <- DBI::dbGetQuery(
  #   con,
  #   sprintf(
  #     "
  #   DESCRIBE
  #   SELECT *
  #   FROM read_json_auto(
  #     '%s',
  #     union_by_name = true,
  #     sample_size = -1,             -- scan all rows for types (streamed by DuckDB)
  #     maximum_sample_files = %d     -- look at all jsonl files
  #   )
  # ",
  #     json_glob,
  #     length(json_files)
  #   )
  # )

  # ## 2) Build columns = {col: 'TYPE', ...} from DESCRIBE output

  # # DuckDB usually returns column_name / column_type; fall back to name / type if needed
  # name_col <- if ("column_name" %in% names(schema)) "column_name" else "name"
  # type_col <- if ("column_type" %in% names(schema)) "column_type" else "type"

  # columns_expr <- paste(
  #   sprintf("%s: '%s'", schema[[name_col]], schema[[type_col]]),
  #   collapse = ",\n      "
  # )

  # # Optional: inspect what will be forced
  # cat("columns = {\n", columns_expr, "\n}\n")

  # ## 3) Per-file loop: JSONL -> Parquet with fixed schema

  # for (fn in json_files) {
  #   sql <- sprintf(
  #     "
  #   COPY (
  #     SELECT
  #       *
  #     FROM
  #       read_json_auto(
  #         '%s',
  #         columns = {
  #           %s
  #         }
  #       )
  #   ) TO
  #     '%s'
  #   (FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY 'page', APPEND);
  # ",
  #     fn,
  #     columns_expr,
  #     output
  #   )

  #   DBI::dbExecute(conn = con, sql)
  # }

  if (delete_input) {
    unlink(input_jsonl, recursive = TRUE, force = TRUE)
  }

  return(invisible(normalizePath(output)))
}
