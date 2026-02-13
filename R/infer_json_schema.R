#' Infer unified JSON schema using DuckDB
#'
#' Reads a sample of JSON/NDJSON files via DuckDB's `read_json_auto()` with
#' `union_by_name = true` and returns a DuckDB `columns` clause string that
#' can be passed to `read_json()` to enforce a consistent schema across files.
#'
#' @param con An active DuckDB connection with the JSON extension loaded.
#' @param files Character vector of JSON/NDJSON file paths to sample.
#' @param sample_size Number of files to sample for schema inference.
#'   Use `0` or `NULL` to use all files. Default is `20`.
#' @param extra_options Additional `read_json_auto` options appended to the SQL,
#'   e.g. `", maximum_object_size=1000000000"`. Default is `""`.
#' @param verbose If `TRUE`, print progress messages. Default is `TRUE`.
#'
#' @return A DuckDB columns clause string like
#'   `"{'col1': 'VARCHAR', 'col2': 'BIGINT', ...}"`, or `NULL` if schema
#'   inference fails.
#'
#' @noRd
infer_json_schema <- function(
  con,
  files,
  sample_size = 20,
  extra_options = "",
  verbose = TRUE
) {
  if (length(files) == 0) {
    if (verbose) message("No files provided for schema inference.")
    return(NULL)
  }

  # Sample files if requested ----
  if (!is.null(sample_size) && sample_size > 0 && length(files) > sample_size) {
    files <- sample(files, sample_size)
  }

  if (verbose) message("Inferring unified schema from ", length(files), " files...")

  # Build file list for DuckDB ----
  file_list <- paste0("['", paste(files, collapse = "','"), "']")

  schema_sql <- sprintf(
    "DESCRIBE SELECT * FROM read_json_auto(%s, union_by_name = true%s)",
    file_list,
    extra_options
  )

  unified_schema <- tryCatch(
    DBI::dbGetQuery(con, schema_sql),
    error = function(e) {
      if (verbose) {
        message("Could not infer unified schema: ", e$message)
      }
      NULL
    }
  )

  if (is.null(unified_schema) || nrow(unified_schema) == 0) {
    return(NULL)
  }

  # Build columns clause ----
  # DuckDB may use different column names for DESCRIBE output
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

  columns_clause
}

#' Convert a single JSON/NDJSON file to Parquet using DuckDB
#'
#' Creates a per-worker DuckDB connection, reads one input file, and writes
#' one `.parquet` output file. Designed to be called from [future.apply::future_lapply()]
#' where each worker needs its own isolated connection.
#'
#' @param input_file Path to the input file (`.json`, `.gz`, etc.).
#' @param output_file Full path for the output `.parquet` file.
#'   Parent directories are created automatically.
#' @param columns_clause DuckDB columns clause from [infer_json_schema()],
#'   or `NULL` to use `read_json_auto()`.
#' @param extra_options Additional `read_json`/`read_json_auto` options string,
#'   e.g. `", maximum_object_size=1000000000"`. Default is `""`.
#' @param memory_limit DuckDB memory limit (e.g., `"8GB"`), or `NULL`.
#' @param temp_directory DuckDB temp directory, or `NULL`.
#'
#' @return The path to the created parquet file (`output_file`).
#' @noRd
convert_json_to_parquet <- function(
  input_file,
  output_file,
  columns_clause = NULL,
  extra_options = "",
  memory_limit = NULL,
  temp_directory = NULL
) {
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

  con <- DBI::dbConnect(duckdb::duckdb(), read_only = FALSE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  DBI::dbExecute(conn = con, "INSTALL json; LOAD json;")
  if (!is.null(memory_limit)) {
    DBI::dbExecute(conn = con, paste0("SET memory_limit = '", memory_limit, "'"))
  }
  if (!is.null(temp_directory)) {
    DBI::dbExecute(conn = con, paste0("SET temp_directory='", temp_directory, "'"))
  }

  # Build read function ----
  read_fn <- if (!is.null(columns_clause)) {
    sprintf("read_json('%s', columns = %s%s)", input_file, columns_clause, extra_options)
  } else {
    sprintf("read_json_auto('%s'%s)", input_file, extra_options)
  }

  sql <- sprintf(
    "COPY (SELECT * FROM %s) TO '%s' (FORMAT PARQUET, COMPRESSION SNAPPY, ROW_GROUP_SIZE 100000)",
    read_fn,
    output_file
  )

  DBI::dbExecute(conn = con, sql)
  output_file
}
