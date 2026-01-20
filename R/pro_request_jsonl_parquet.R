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
#' When starting the conversion, a file `00_in.progress` which is deleted upon completion.
#'
#' @param input_jsonl The directory of JSON files returned from
#'   `pro_request(..., json_dir = "FOLDER")`.
#' @param output output directory for the parquet dataset; default: temporary
#'   directory.
#' @param overwrite Logical indicating whether to overwrite `output`.
#' @param verbose Logical indicating whether to show a verbose information.
#'   Defaults to `TRUE`
#' @param progress Logical indicating whether to show a progress bar. Default `TRUE`.
#' @param delete_input Determines if the `input_jsonl` should be deleted
#'   afterwards. Defaults to `FALSE`.
#' @param sample_size Number of records to sample from each file when inferring
#'   the unified schema. Higher values give more accurate schema inference but
#'   use more memory. Default is 1000. Set to -1 to read all records (may be slow
#'   for large files).
#'
#' @return The function does returns the output invisibly.
#'
#' @details The function uses DuckDB to read the JSON files and to create the
#'   Apache Parquet files. The function creates a DuckDB connection in memory
#'   and reads the JSON files into DuckDB when needed. Then it creates a SQL
#'   query to convert the JSON files to Apache Parquet files and to copy the
#'   result to the specified directory.
#'
#'   To ensure consistent schemas across all Parquet files, the function first
#'   infers a unified schema by sampling records from all JSONL files. This
#'   prevents type mismatches (e.g., a column being `struct` in one file but
#'   `string` in another) that would cause errors when reading the combined
#'   Parquet dataset.
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery
#' @importFrom cli cli_progress_bar cli_progress_update cli_progress_done cli_alert_info
#'
#' @md
#'
#' @export

pro_request_jsonl_parquet <- function(
  input_jsonl = NULL,
  output = NULL,

  overwrite = FALSE,
  verbose = TRUE,
  progress = TRUE,
  delete_input = FALSE,
  sample_size = 1000
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
  }
  dir.create(
    output,
    recursive = TRUE,
    showWarnings = FALSE
  )
  progress_file <- file.path(output, "00_in.progress")
  file.create(progress_file)
  success <- FALSE
  on.exit(
    {
      if (isTRUE(success)) {
        unlink(progress_file)
      }
    },
    add = TRUE
  )

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

  if (length(jsons) == 0) {
    stop("No JSON files found in `input_jsonl`!")
  }

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

  # Infer unified schema from all JSONL files ------------------------------
  if (verbose) {
    message("Inferring unified schema from all JSONL files...")
  }

  glob_pattern <- file.path(input_jsonl, "**/*.json")

  # Build sample limit clause
  sample_clause <- if (sample_size > 0) {
    sprintf("LIMIT %d", sample_size)
  } else {
    ""
  }

  # Infer unified schema by reading a sample from all files together

  # DuckDB's read_json_auto with union_by_name handles schema unification
  unified_schema_sql <- sprintf(
    "
    DESCRIBE
    SELECT *
    FROM read_json_auto('%s', union_by_name = true, sample_size = %d)
    %s
    ",
    glob_pattern,
    if (sample_size > 0) sample_size else -1,
    sample_clause
  )

  unified_schema <- tryCatch(
    {
      DBI::dbGetQuery(con, unified_schema_sql)
    },
    error = function(e) {
      if (verbose) {
        message("Could not infer unified schema, falling back to per-file inference: ", e$message)
      }
      NULL
    }
  )

  # Build column definitions for read_json if we have a unified schema
  columns_clause <- NULL
  if (!is.null(unified_schema) && nrow(unified_schema) > 0) {
    # Get column names - DuckDB may use different field names
    name_col <- if ("column_name" %in% names(unified_schema)) "column_name" else "name"
    type_col <- if ("column_type" %in% names(unified_schema)) "column_type" else "type"

    col_defs <- mapply(
      function(nm, tp) sprintf("'%s': '%s'", nm, tp),
      unified_schema[[name_col]],
      unified_schema[[type_col]],
      SIMPLIFY = TRUE,
      USE.NAMES = FALSE
    )
    columns_clause <- paste0("{", paste(col_defs, collapse = ", "), "}")

    if (verbose) {
      message("Unified schema inferred with ", nrow(unified_schema), " columns")
    }
  }

  # Go through all jsons, i.e. one per page --------------------------------
  ### Names: results_page_x.json

  # Setup progress bar (sequential loop uses cli directly)
  if (progress) {
    cli::cli_progress_bar(
      total = length(jsons),
      format = "Converting to Parquet {cli::pb_bar} {cli::pb_current}/{cli::pb_total} [{cli::pb_elapsed}]"
    )
  }

  for (i in seq_along(jsons)) {
    fn <- jsons[i]
    if (verbose) {
      message("Converting ", i, " of ", length(jsons), " : ", fn)
    }

    try(
      {
        # Use read_json with explicit columns if we have a unified schema,
        # otherwise fall back to read_json_auto
        if (!is.null(columns_clause)) {
          sql <- sprintf(
            "
                COPY (
                  SELECT
                    *
                  FROM
                    read_json('%s', columns = %s, auto_detect = true)
                ) TO
                  '%s'
                (FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY 'page', APPEND)
            ",
            fn,
            columns_clause,
            output
          )
        } else {
          sql <- sprintf(
            "
                COPY (
                  SELECT
                    *
                  FROM
                    read_json_auto('%s')
                ) TO
                  '%s'
                (FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY 'page', APPEND)
            ",
            fn,
            output
          )
        }
        DBI::dbExecute(conn = con, sql)
        if (verbose) {
          message("   Done")
        }
      },
      silent = !verbose
    )

    if (progress) {
      cli::cli_progress_update()
    }
  }

  if (progress) {
    cli::cli_progress_done()
  }

  if (delete_input) {
    unlink(input_jsonl, recursive = TRUE, force = TRUE)
  }

  success <- TRUE

  return(invisible(normalizePath(output)))
}
