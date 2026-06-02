#' Convert JSON files from pro_request() directly to Apache Parquet
#'
#' Single-step replacement for the two-step
#' `pro_request_jsonl_R()` + `pro_request_jsonl_parquet()` pipeline.
#' Reads the JSON files written by [pro_request()] and converts each one to a
#' Parquet file using DuckDB, with no intermediate JSONL on disk.
#'
#' For works entities the function detects the presence of
#' `abstract_inverted_index`, `authorships`, and `publication_year` in the
#' inferred schema and, when `enrich = TRUE` (the default), adds two computed
#' columns:
#' - **`abstract`** — plain text reconstructed from `abstract_inverted_index`.
#' - **`citation`** — `"Author (year)"` / `"A & B (year)"` / `"A et al. (year)"`.
#'
#' These expressions are identical to those used by the `openalex-snapshot` CLI
#' binary, so the Parquet output matches the snapshot pipeline column for column.
#'
#' @section File format:
#' [pro_request()] writes one JSON file per API page.  For paginated queries
#' each file has the structure `{"results": [...], "meta": {...}}`.  For
#' group-by queries the array field is `"group_by"`.  For single-record lookups
#' the file is a bare JSON object.  All three formats are handled automatically.
#'
#' @section Output layout:
#' The subdirectory structure of `input_json` is preserved, with hive-partition
#' naming (`query=<name>/`, `query_l2=<name>/`, …) so that Arrow/DuckDB can
#' read the result as a partitioned dataset.  A `page` column is added to each
#' record with a value derived from the source filename (or subdirectory for
#' multi-query inputs).
#'
#' @param input_json Directory of JSON files returned by [pro_request()].
#' @param output Output directory for the Parquet dataset.
#' @param add_columns Named list of scalar constant columns to embed in every
#'   output record (e.g. `list(query = "my_filter")`).  Values are embedded as
#'   SQL string literals; only character scalars are supported.
#' @param overwrite Logical.  Overwrite `output` if it already exists.
#'   Default `FALSE`.
#' @param verbose Logical.  Show progress messages.  Default `TRUE`.
#' @param progress Logical.  Show a progress bar.  Default `TRUE`.
#' @param delete_input Logical.  Delete `input_json` after a successful
#'   conversion.  Default `FALSE`.
#' @param sample_size Integer.  Number of records per file passed to DuckDB's
#'   `sample_size` option during schema inference.  Use `-1` to read all
#'   records (accurate but slow for large files).  Default `1000`.
#' @param workers Integer.  Number of parallel workers.
#'   `NULL` or `1` runs sequentially.  Default `NULL`.
#' @param enrich Logical.  When `TRUE` (the default) and the inferred schema
#'   contains `abstract_inverted_index` / `authorships` / `publication_year`,
#'   add `abstract` and `citation` computed columns.
#' @param schema Controls use of a pre-built baseline schema for type
#'   resolution.  Possible values:
#'   \describe{
#'     \item{`"auto"` (default)}{Auto-detect the OpenAlex entity type from the
#'       inferred columns, then load the matching schema from the user cache
#'       (populated by \code{\link{oa_cache_schema}()}) or the schemas bundled
#'       with the package.  For each column where DuckDB runtime inference
#'       produced the ambiguous `JSON` fallback type, the baseline type is used
#'       instead.  Falls back silently to runtime-only inference when the entity
#'       cannot be detected or no schema is found.}
#'     \item{`"none"` or `NULL`}{Skip the baseline entirely; behaviour is
#'       identical to package versions before this feature was added.}
#'     \item{A file path}{Path to a CSV with columns `col_name` / `col_type`.
#'       Used directly as the baseline.}
#'     \item{A directory path}{Auto-detect entity, then look for
#'       `<entity>.csv` inside that directory.  Useful when pointing directly
#'       at a snapshot-metadata schemata directory.}
#'   }
#'
#' @return Output directory path (invisibly).
#'
#' @seealso [pro_request()] to download the JSON files,
#'   [pro_request_jsonl_R()] and [pro_request_jsonl_parquet()] for the older
#'   two-step pipeline (now deprecated).
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery
#' @importFrom future plan multisession sequential
#' @importFrom future.apply future_lapply
#' @importFrom cli cli_alert_info
#' @importFrom progressr with_progress progressor handlers
#'
#' @md
#'
#' @export
pro_request_parquet <- function(
  input_json = NULL,
  output = NULL,
  add_columns = list(),
  overwrite = FALSE,
  verbose = TRUE,
  progress = TRUE,
  delete_input = FALSE,
  sample_size = 1000,
  workers = NULL,
  enrich = TRUE,
  schema = "auto"
) {
  if (is.null(input_json)) stop("No `input_json` specified!")
  if (is.null(output))     stop("No `output` specified!")

  progress_file <- .prr_prepare_output(output, overwrite)
  success <- FALSE
  on.exit({ if (isTRUE(success)) unlink(progress_file) }, add = TRUE)

  disc      <- .prr_discover_jsons(input_json)
  schema_df <- .prr_infer_schema(
    disc$jsons, disc$array_field, sample_size, schema, verbose
  )
  list_type <- attr(schema_df, "list_type")

  present_cols <- if (!is.null(schema_df)) schema_df$column_name else character(0L)
  abstract_sql <- if (enrich && "abstract_inverted_index" %in% present_cols) {
    oa_works_abstract_sql()
  } else NULL
  citation_sql <- if (enrich && all(c("authorships", "publication_year") %in% present_cols)) {
    oa_works_citation_sql()
  } else NULL

  output_files <- .prr_output_paths(disc$jsons, input_json, output)

  if (!is.null(workers) && workers > 1L) {
    old_plan <- future::plan(future::multisession, workers = workers)
    on.exit(future::plan(old_plan), add = TRUE)
  }

  if (progress) {
    cli::cli_alert_info("Converting {length(disc$jsons)} JSON file{?s} to Parquet")
    progressr::handlers("cli")
  }

  .array_field  <- disc$array_field
  .has_subdirs  <- disc$has_subdirs
  .list_type    <- list_type
  .abstract_sql <- abstract_sql
  .citation_sql <- citation_sql
  .add_columns  <- add_columns
  .verbose      <- verbose
  jsons         <- disc$jsons

  progressr::with_progress({
    p <- if (progress) progressr::progressor(steps = length(jsons)) else NULL
    future.apply::future_lapply(seq_along(jsons), function(i) {
      .prr_convert_one(
        fn           = jsons[[i]],
        out_fn       = output_files[[i]],
        array_field  = .array_field,
        has_subdirs  = .has_subdirs,
        list_type    = .list_type,
        abstract_sql = .abstract_sql,
        citation_sql = .citation_sql,
        add_columns  = .add_columns,
        verbose      = .verbose
      )
      if (!is.null(p)) p()
      invisible(NULL)
    })
  }, enable = progress)

  if (delete_input) unlink(input_json, recursive = TRUE, force = TRUE)

  success <- TRUE
  invisible(normalizePath(output))
}

# Helpers --------------------------------------------------------------------

#' @keywords internal
#' @noRd
.prr_prepare_output <- function(output, overwrite) {
  if (file.exists(output)) {
    if (!overwrite) {
      stop(
        "output ", output, " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    }
    unlink(output, recursive = TRUE, force = TRUE)
  }
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  progress_file <- file.path(output, "00_in.progress")
  file.create(progress_file)
  progress_file
}

#' @keywords internal
#' @noRd
.prr_discover_jsons <- function(input_json) {
  jsons <- list.files(
    input_json, pattern = "\\.json$", full.names = TRUE, recursive = TRUE
  )
  jsons <- jsons[order(as.numeric(
    sub(".*_([0-9]+)\\.json$", "\\1", jsons)
  ))]
  if (length(jsons) == 0) stop("No JSON files found in `input_json`!")

  types <- unique(vapply(
    basename(jsons),
    function(b) strsplit(b, "_")[[1L]][1L],
    character(1L)
  ))
  if (length(types) > 1L) stop("Mixed entity types found in `input_json`!")
  entity_type <- if (identical(types, "group")) "group_by" else types
  array_field <- switch(
    entity_type, results = "results", group_by = "group_by", NULL
  )

  list(
    jsons       = jsons,
    array_field = array_field,
    has_subdirs = length(list.dirs(input_json, recursive = FALSE)) > 0
  )
}

#' @keywords internal
#' @noRd
.prr_infer_schema <- function(jsons, array_field, sample_size, schema, verbose) {
  sample_opt <- if (isTRUE(sample_size > 0)) {
    sprintf(", sample_size = %d", as.integer(sample_size))
  } else {
    ""
  }
  infer_files <- if (length(jsons) > 20L) sample(jsons, 20L) else jsons
  files_sql   <- paste0("[", paste0("'", infer_files, "'", collapse = ", "), "]")

  if (verbose) message("Inferring schema from ", length(infer_files), " sampled file(s)...")

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "INSTALL json; LOAD json;")

  if (is.null(array_field)) {
    schema_sql <- sprintf(
      "DESCRIBE SELECT * FROM read_json(%s, ignore_errors = true%s)",
      files_sql, sample_opt
    )
    schema_df <- tryCatch(DBI::dbGetQuery(con, schema_sql), error = function(e) NULL)
    return(schema_df)
  }

  schema_sql <- sprintf(
    "DESCRIBE SELECT r.* FROM (SELECT unnest(%s) AS r FROM read_json(%s, ignore_errors = true%s))",
    array_field, files_sql, sample_opt
  )
  schema_df <- tryCatch(
    DBI::dbGetQuery(con, schema_sql),
    error = function(e) {
      if (verbose) message("Schema inference failed: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(schema_df) || nrow(schema_df) == 0L) return(schema_df)

  # Force abstract_inverted_index to MAP — DuckDB sometimes infers STRUCT
  # when the sample has no duplicate-cased keys, which breaks map_entries().
  aii_idx <- which(schema_df$column_name == "abstract_inverted_index")
  if (length(aii_idx) == 1L) {
    schema_df$column_type[aii_idx] <- "MAP(VARCHAR, BIGINT[])"
  }

  schema_df <- .prr_apply_baseline(schema_df, schema, verbose)

  struct_fields <- paste(schema_df$column_name, schema_df$column_type, sep = " ")
  list_type <- paste0("STRUCT(", paste(struct_fields, collapse = ", "), ")[]")
  list_type <- .prr_fix_json_types(list_type)
  attr(schema_df, "list_type") <- list_type
  schema_df
}

#' @keywords internal
#' @noRd
.prr_apply_baseline <- function(schema_df, schema, verbose) {
  if (is.null(schema) || identical(schema, "none")) return(schema_df)
  baseline_df <- .resolve_baseline(schema, present_cols = schema_df$column_name)
  if (is.null(baseline_df)) return(schema_df)

  for (.i in seq_len(nrow(schema_df))) {
    rt <- schema_df$column_type[.i]
    if (!grepl("\\bJSON\\b", rt)) next
    col      <- schema_df$column_name[.i]
    base_row <- baseline_df[baseline_df$col_name == col, , drop = FALSE]
    if (nrow(base_row) == 1L) {
      schema_df$column_type[.i] <- base_row$col_type
    }
  }
  if (verbose) {
    message(
      "Applied baseline schema for entity '",
      attr(baseline_df, "entity"), "'."
    )
  }
  schema_df
}

#' @keywords internal
#' @noRd
.prr_fix_json_types <- function(list_type) {
  # Patch known OpenAlex source-struct fields DuckDB may infer as JSON when
  # all sampled values are null — required for union_by_name = true reads.
  list_type <- gsub("\\bissn_l JSON\\b", "issn_l VARCHAR", list_type)
  list_type <- gsub("(?<![_])\\bissn JSON\\b", "issn VARCHAR[]", list_type, perl = TRUE)
  gsub(
    "host_organization_lineage_names JSON\\[\\]",
    "host_organization_lineage_names VARCHAR[]",
    list_type, fixed = TRUE
  )
}

#' @keywords internal
#' @noRd
.prr_output_paths <- function(jsons, input_json, output) {
  input_depth <- length(strsplit(gsub("\\\\", "/", input_json), "/")[[1L]])
  hive_key <- function(depth) if (depth == 1L) "query" else paste0("query_l", depth)

  vapply(jsons, function(f) {
    f_parts <- strsplit(gsub("\\\\", "/", f), "/")[[1L]]
    fname   <- sub("\\.json$", ".parquet", basename(f))
    rel_parts <- if (length(f_parts) > input_depth + 1L) {
      f_parts[seq(input_depth + 1L, length(f_parts) - 1L)]
    } else {
      character(0L)
    }
    if (length(rel_parts) == 0L) return(file.path(output, fname))
    hive_dirs <- mapply(
      function(d, v) paste0(hive_key(d), "=", v),
      seq_along(rel_parts), rel_parts,
      SIMPLIFY = TRUE
    )
    do.call(file.path, c(list(output), as.list(hive_dirs), list(fname)))
  }, character(1L), USE.NAMES = FALSE)
}

#' @keywords internal
#' @noRd
.prr_convert_one <- function(
  fn, out_fn, array_field, has_subdirs, list_type,
  abstract_sql, citation_sql, add_columns, verbose
) {
  pn <- if (has_subdirs) {
    basename(dirname(fn))
  } else {
    sub(".*_([0-9]+)\\.json$", "\\1", basename(fn))
  }
  dir.create(dirname(out_fn), recursive = TRUE, showWarnings = FALSE)

  extras <- character(0L)
  if (!is.null(abstract_sql)) extras <- c(extras, paste0(abstract_sql, " AS abstract"))
  if (!is.null(citation_sql)) extras <- c(extras, paste0(citation_sql, " AS citation"))
  extras <- c(extras, sprintf("'%s' AS page", pn))
  if (length(add_columns) > 0L) {
    extras <- c(
      extras,
      sprintf("'%s' AS %s", as.character(add_columns), names(add_columns))
    )
  }
  extra_select <- if (length(extras) > 0L) {
    paste(",", paste(extras, collapse = ",\n          "))
  } else {
    ""
  }

  sql <- if (!is.null(array_field)) {
    read_spec <- if (!is.null(list_type)) {
      sprintf(
        "read_json('%s', columns = {'%s': '%s', 'meta': 'JSON'})",
        fn, array_field, list_type
      )
    } else {
      sprintf("read_json_auto('%s')", fn)
    }
    sprintf(
      "COPY (
        SELECT *%s
        FROM (
          SELECT r.*
          FROM (SELECT unnest(%s) AS r FROM %s)
        )
      ) TO '%s' (FORMAT PARQUET, COMPRESSION SNAPPY, ROW_GROUP_SIZE 100000)",
      extra_select, array_field, read_spec, out_fn
    )
  } else {
    sprintf(
      "COPY (
        SELECT *%s
        FROM read_json_auto('%s')
      ) TO '%s' (FORMAT PARQUET, COMPRESSION SNAPPY, ROW_GROUP_SIZE 100000)",
      extra_select, fn, out_fn
    )
  }

  worker_con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(worker_con, shutdown = TRUE), add = TRUE)
  tryCatch(
    {
      DBI::dbExecute(worker_con, "INSTALL json; LOAD json;")
      DBI::dbExecute(worker_con, sql)
    },
    error = function(e) {
      if (verbose) {
        message("Failed to convert ", basename(fn), ": ", conditionMessage(e))
      }
    }
  )
}
