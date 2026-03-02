#' Convert OA snapshot to Parquet format
#'
#' This function converts the OA (OpenAlex) snapshot data to Parquet format,
#' processing each `.gz` file individually. Existing output files are skipped,
#' allowing interrupted conversions to resume. On macOS, a `.metadata_never_index`
#' file is created in the output directory to prevent Spotlight from indexing
#' the parquet files.
#'
#' @param snapshot_dir The directory path of the OA snapshot data.
#'   Default is `"Volumes/openalex/openalex-snapshot"`.
#' @param parquet_dir The directory path where the Parquet files will be saved.
#'   Default is `"Volumes/openalex/parquet"`.
#' @param data_sets A character vector specifying the data sets to process.
#'   Default is `NULL`, which processes all data sets.
#' @param sample_size Number of `.gz` files to sample for unified schema
#'   inference. Higher values give more accurate schemas but take longer.
#'   Default is `20`. Use `NULL` or `0` to use all files.
#' @param temp_directory Location of the temporary directory for DuckDB.
#'   Passed to each worker's DuckDB connection. Default is `NULL` (system default).
#' @param memory_limit DuckDB memory limit per worker (e.g., `"8GB"`).
#'   Default is `NULL` (DuckDB default).
#' @param workers Number of parallel workers for file conversion via
#'   [future.apply::future_lapply()]. Default is `NULL` (sequential processing).
#'
#' @details
#' The conversion proceeds in two stages for each data set:
#'
#' 1. **Schema inference**: A sample of `.gz` files is read using DuckDB's
#'    `read_json_auto()` with `union_by_name = true` to infer a unified schema.
#'    This ensures all output parquet files have consistent column types.
#'
#' 2. **Per-file conversion**: Each `.gz` file is converted individually to a
#'    `.parquet` file. When `workers > 1`, files are processed in parallel using
#'    [future::multisession], with each worker creating its own DuckDB connection.
#'
#' Already-converted files (those with a matching `.parquet` output) are
#' automatically skipped, so the function can resume after interruption.
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#' @importFrom duckdb duckdb
#' @importFrom future plan multisession sequential
#' @importFrom future.apply future_lapply
#' @importFrom progressr with_progress progressor handler_cli
#'
#' @examples
#' \dontrun{
#' # Convert all data sets in the default snapshot directory
#' snapshot_to_parquet()
#'
#' # Convert specific data sets with parallel processing
#' snapshot_to_parquet(
#'   snapshot_dir = "/path/to/snapshot",
#'   data_sets = c("authors", "works"),
#'   workers = 4,
#'   memory_limit = "8GB"
#' )
#' }
#'
#' @export
#' @md
snapshot_to_parquet <- function(
  snapshot_dir = file.path("", "Volumes", "openalex", "openalex-snapshot"),
  parquet_dir = file.path("", "Volumes", "openalex", "parquet"),
  data_sets = NULL,
  sample_size = 20,
  temp_directory = NULL,
  memory_limit = NULL,
  workers = NULL
) {
  if (is.null(data_sets)) {
    data_sets <- list.dirs(
      file.path(snapshot_dir, "data"),
      recursive = FALSE,
      full.names = FALSE
    )
    # Remove merged_ids ----
    data_sets <- data_sets[data_sets != "merged_ids"]
  }

  dir.create(parquet_dir, recursive = TRUE, showWarnings = FALSE)

  # Prevent macOS Spotlight from indexing parquet files ----
  file.create(file.path(parquet_dir, ".metadata_never_index"))

  # Set up parallel plan if workers > 1 ----
  if (!is.null(workers) && workers > 1) {
    oldPlan <- future::plan(future::multisession, workers = workers)
    on.exit(future::plan(oldPlan), add = TRUE)
  }

  for (data_set in data_sets) {
    parquet_ds <- file.path(parquet_dir, data_set)
    json_dir <- file.path(snapshot_dir, "data", data_set)

    message("Processing ", data_set, " ...")
    ds_start <- Sys.time()

    # Enumerate all .gz files ----
    gz_files <- list.files(
      json_dir,
      pattern = "\\.gz$",
      recursive = TRUE,
      full.names = TRUE
    )

    if (length(gz_files) == 0) {
      warning(
        "No .gz files found for '",
        data_set,
        "', skipping.",
        call. = FALSE
      )
      next
    }

    # Compute relative paths from json_dir.
    # normalizePath() uses \ on Windows; gsub ensures / on all platforms so
    # the %in% comparison with list.files() output is consistent. ----
    json_dir_norm <- normalizePath(json_dir)
    rel_paths <- vapply(gz_files, function(f) {
      gsub("\\\\", "/", substring(normalizePath(f), nchar(json_dir_norm) + 2))
    }, character(1), USE.NAMES = FALSE)

    # Resume support: skip already-converted files ----
    dir.create(parquet_ds, recursive = TRUE, showWarnings = FALSE)
    existing_parquets <- gsub("\\\\", "/", list.files(
      parquet_ds,
      pattern = "\\.parquet$",
      recursive = TRUE,
      full.names = FALSE
    ))
    expected_parquets <- sub("\\.gz$", ".parquet", rel_paths)
    todo_mask <- !(expected_parquets %in% existing_parquets)
    skipped <- sum(!todo_mask)
    if (skipped > 0) {
      message("  Skipping ", skipped, " already converted file(s)")
    }
    gz_files <- gz_files[todo_mask]
    output_files <- file.path(parquet_ds, expected_parquets[todo_mask])

    if (length(gz_files) == 0) {
      message("  All files already converted.")
      next
    }

    message("  Converting ", length(gz_files), " file(s)...")

    # Stage 1: Infer unified schema ----
    ndjson_options <- if (data_set == "works") {
      ", maximum_object_size=1000000000"
    } else {
      ""
    }

    con <- DBI::dbConnect(duckdb::duckdb(), read_only = FALSE)
    DBI::dbExecute(conn = con, "INSTALL json; LOAD json;")
    if (!is.null(memory_limit)) {
      DBI::dbExecute(conn = con, paste0("SET memory_limit = '", memory_limit, "'"))
    }
    if (!is.null(temp_directory)) {
      DBI::dbExecute(conn = con, paste0("SET temp_directory = '", temp_directory, "'"))
    }
    columns_clause <- infer_json_schema(
      con = con,
      files = gz_files,
      sample_size = sample_size,
      extra_options = ndjson_options,
      verbose = TRUE,
      schema_cache_dir = file.path(parquet_ds, ".schema_cache")
    )
    DBI::dbDisconnect(con, shutdown = TRUE)

    # For works: abstract_inverted_index has duplicate JSON keys ("as" vs "As")
    # that DuckDB case-folds to the same struct field name, causing a collision.
    # Override the type to VARCHAR so DuckDB reads the raw JSON text instead of
    # building a STRUCT, which avoids the collision entirely. ----
    if (data_set == "works" && !is.null(columns_clause)) {
      columns_clause <- gsub(
        "'abstract_inverted_index':\\s*'[^']*'",
        "'abstract_inverted_index': 'VARCHAR'",
        columns_clause
      )
      message("  Storing 'abstract_inverted_index' as VARCHAR (raw JSON string)")
    }

    # Stage 2: Per-file conversion ----
    progressr::with_progress(
      {
        p <- progressr::progressor(along = gz_files)

        future.apply::future_lapply(seq_along(gz_files), function(i) {
          result <- convert_json_to_parquet(
            input_file = gz_files[i],
            output_file = output_files[i],
            columns_clause = columns_clause,
            extra_options = ndjson_options,
            memory_limit = memory_limit,
            temp_directory = temp_directory
          )
          p()
          result
        })
      },
      handlers = progressr::handler_cli()
    )

    message(
      "  done after ",
      round(difftime(Sys.time(), ds_start, units = "secs"), 2),
      " seconds"
    )
  }
}
