#' Harmonize Parquet Schemas In-Place
#'
#' Inspect every Parquet file inside a (possibly hive-partitioned) directory,
#' infer a *global unified schema* across all files, and rewrite only those
#' files whose column types deviate from this global schema.
#'
#' Directory structure and file names are preserved. Only files with
#' mismatched column types are rewritten.
#'
#' Typical use case: large JSON → Parquet ingestion pipelines where DuckDB
#' infers slightly different types for rare fields across pages (e.g. `fwci`
#' sometimes `INT`, sometimes `DOUBLE`).
#'
#' @param root_dir Character path to the root directory containing Parquet
#'   files. Can be hive-partitioned (e.g. `page=1/`, `page=2/`, …) or flat;
#'   the function always scans recursively.
#' @param compression Parquet compression codec. Default `"SNAPPY"`.
#' @param verbose Logical; whether to report progress. Default `TRUE`.
#'
#' @return Invisibly returns `TRUE` on success.
#'
#' @details
#' The function performs three steps:
#'
#' \enumerate{
#'   \item Uses DuckDB to infer a *global schema* across all Parquet files via
#'   \code{DESCRIBE SELECT * FROM parquet_scan('root_dir/**/*.parquet')}.
#'
#'   \item For each file, obtains its *local schema* via
#'   \code{DESCRIBE SELECT * FROM parquet_scan('file')}.
#'
#'   \item If any column has a different type from the global type, rewrites
#'   that file using:
#'
#'   \preformatted{
#'   SELECT
#'     *
#'     REPLACE (
#'       CAST(col AS global_type) AS col,
#'       ...
#'     )
#'   FROM parquet_scan('file')
#'   }
#'
#'   and writes it to a temporary Parquet file, which then atomically
#'   replaces the original.
#' }
#'
#' Missing columns are *not* rewritten; Parquet readers naturally treat them as
#' nullable and fill `NULL`s where absent. Only mismatched column *types*
#' trigger a rewrite.
#'
#' If the `progressr` package is installed and `verbose = TRUE`, a progress bar
#' is shown; otherwise files are processed in a simple loop.
#'
#' @examples
#' \dontrun{
#' harmonize_parquet_schemata("data/hive_dataset")
#' }
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery dbQuoteIdentifier dbQuoteString
#' @importFrom dplyr transmute inner_join filter
#' @importFrom rlang .data
#' @export
harmonize_parquet_schemata <- function(
  root_dir,
  compression = "SNAPPY",
  verbose = TRUE
) {
  root_dir <- normalizePath(root_dir, mustWork = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # -------------------------------------------------------------------
  # 0. List all parquet files under root_dir (keeps hive layout if present)
  # -------------------------------------------------------------------
  files <- list.files(
    root_dir,
    pattern = "\\.parquet$",
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(files) == 0L) {
    stop("No .parquet files found under: ", root_dir)
  }

  # -------------------------------------------------------------------
  # 1. Global unified schema across ALL parquet files (recursive scan)
  # -------------------------------------------------------------------
  glob <- file.path(root_dir, "**/*.parquet")
  glob_sql <- DBI::dbQuoteString(con, glob)

  if (verbose) {
    message("Inferring global schema from ", glob)
  }

  global_schema_raw <- DBI::dbGetQuery(
    con,
    sprintf(
      "
      DESCRIBE
      SELECT *
      FROM parquet_scan(%s)
      ",
      glob_sql
    )
  )

  # DuckDB fields: either (column_name, column_type) or (name, type)
  name_col <- if ("column_name" %in% names(global_schema_raw)) {
    "column_name"
  } else {
    "name"
  }

  type_col <- if ("column_type" %in% names(global_schema_raw)) {
    "column_type"
  } else {
    "type"
  }

  global_schema <- global_schema_raw |>
    dplyr::transmute(
      column_name = .data[[name_col]],
      global_type = .data[[type_col]]
    )

  if (verbose) {
    message("Global schema columns: ", nrow(global_schema))
    message("Checking ", length(files), " parquet files.")
  }

  # -------------------------------------------------------------------
  # 2. For each file: compare schema with global, rewrite if needed
  # -------------------------------------------------------------------
  harmonize_single <- function(f, progress = NULL) {
    f_norm <- normalizePath(f)
    f_sql <- DBI::dbQuoteString(con, f_norm)

    if (!is.null(progress)) {
      progress(message = basename(f_norm))
    }

    if (verbose) {
      message("File: ", f_norm)
    }

    local_schema_raw <- DBI::dbGetQuery(
      con,
      sprintf(
        "
        DESCRIBE
        SELECT *
        FROM parquet_scan(%s)
        ",
        f_sql
      )
    )

    name_col_local <- if ("column_name" %in% names(local_schema_raw)) {
      "column_name"
    } else {
      "name"
    }

    type_col_local <- if ("column_type" %in% names(local_schema_raw)) {
      "column_type"
    } else {
      "type"
    }

    local_schema <- local_schema_raw |>
      dplyr::transmute(
        column_name = .data[[name_col_local]],
        file_type = .data[[type_col_local]]
      )

    merged <- dplyr::inner_join(local_schema, global_schema, by = "column_name")

    diff_cols <- merged |>
      dplyr::filter(file_type != global_type, !is.na(global_type))

    if (nrow(diff_cols) == 0L) {
      if (verbose) {
        message("  -> schema OK, no rewrite needed.")
      }
      return(invisible(FALSE))
    }

    if (verbose) {
      message(
        "  -> schema differs for columns: ",
        paste(diff_cols$column_name, collapse = ", ")
      )
    }

    # Build CAST expressions for REPLACE (protecting identifiers)
    cast_lines <- character(nrow(diff_cols))
    for (i in seq_len(nrow(diff_cols))) {
      col_name <- diff_cols$column_name[i]
      col_type <- diff_cols$global_type[i]
      col_id_sql <- DBI::dbQuoteIdentifier(con, col_name)

      cast_lines[i] <- sprintf(
        "CAST(%s AS %s) AS %s",
        col_id_sql,
        col_type,
        col_id_sql
      )
    }
    replace_expr <- paste(cast_lines, collapse = ",\n        ")

    select_sql <- sprintf(
      "
      SELECT
        *
        REPLACE (
          %s
        )
      FROM parquet_scan(%s)
      ",
      replace_expr,
      f_sql
    )

    tmp_f <- paste0(f_norm, ".tmp")
    tmp_f_sql <- DBI::dbQuoteString(con, tmp_f)
    compression_sql <- DBI::dbQuoteString(con, compression)

    copy_sql <- sprintf(
      "
      COPY (
        %s
      ) TO %s
      (FORMAT PARQUET, COMPRESSION %s);
      ",
      select_sql,
      tmp_f_sql,
      compression_sql
    )

    if (verbose) {
      message("  -> rewriting to temporary file: ", tmp_f)
    }

    DBI::dbExecute(con, copy_sql)

    if (verbose) {
      message("  -> replacing original file.")
    }

    ok_rm <- file.remove(f_norm)
    ok_mv <- file.rename(tmp_f, f_norm)

    if (!ok_rm || !ok_mv) {
      stop("Failed to replace original file with harmonized version: ", f_norm)
    }

    invisible(TRUE)
  }

  if (verbose && requireNamespace("progressr", quietly = TRUE)) {
    progressr::with_progress({
      p <- progressr::progressor(along = files)
      for (f in files) {
        harmonize_single(f, p)
      }
    })
  } else {
    for (f in files) {
      harmonize_single(f, NULL)
    }
  }

  if (verbose) {
    message("Done harmonizing schemas in-place under: ", root_dir)
  }

  invisible(TRUE)
}
