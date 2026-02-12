#' Convert OA snapshot to Parquet format
#'
#' This function converts the OA (openalex) snapshot data to Parquet format.
#' Existing datasets are skipped with a warning. On macOS, a `.metadata_never_index`
#' file is created in the output directory to prevent Spotlight from indexing
#' the parquet files.
#'
#' @param snapshot_dir The directory path of the OA snapshot data. Default is "Volumes/openalex/openalex-snapshot".
#' @param parquet_dir The directory path where the Parquet files will be saved. Default is "Volumes/openalex/parquet".
#' @param data_sets A character vector specifying the data sets to process. Default is NULL, which processes all data sets.
#' @param temp_directory location of the temporaty directory for duckdb. Initial runs indicate
#'   that 2TB should be safe. Default is `NULL`, use the system temporary directory.
#' @param memory_limit DuckDB memory limit (e.g., "64GB"). Set to 50-60% of
#'   system RAM for optimal performance. Default is `NULL`, use DuckDB default.
#' @param workers Number of DuckDB threads to use. Lower values reduce memory
#'   usage but slow down processing. Default is `NULL`, use all available cores.
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#' @importFrom duckdb duckdb
#'
#' @examples
#' \dontrun{
#' # Convert all data sets in the default snapshot directory
#' snapshot_to_parquet()
#'
#' # Convert specific data sets in a custom snapshot directory
#' snapshot_to_parquet(snapshot_dir = "/path/to/snapshot", data_sets = c("data_set1", "data_set2"))
#' }
#'
#' @export
#' @md
snapshot_to_parquet <- function(
  snapshot_dir = file.path("", "Volumes", "openalex", "openalex-snapshot"),
  parquet_dir = file.path("", "Volumes", "openalex", "parquet"),
  data_sets = NULL,
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
    # Remove merged_dirs ----
    data_sets <- data_sets[data_sets != "merged_ids"]
  }

  dir.create(parquet_dir, recursive = TRUE, showWarnings = FALSE)

  # Prevent macOS Spotlight from indexing parquet files ----
  file.create(file.path(parquet_dir, ".metadata_never_index"))

  con <- DBI::dbConnect(duckdb::duckdb(), read_only = FALSE)

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  DBI::dbExecute(conn = con, "INSTALL json")
  DBI::dbExecute(conn = con, "LOAD json")
  if (!is.null(temp_directory)) {
    DBI::dbExecute(
      conn = con,
      paste0("set temp_directory='", temp_directory, "'")
    )
  }

  DBI::dbExecute(conn = con, "SET preserve_insertion_order = false")
  DBI::dbExecute(conn = con, "SET partitioned_write_max_open_files = 50")
  if (!is.null(memory_limit)) {
    DBI::dbExecute(
      conn = con,
      paste0("SET memory_limit = '", memory_limit, "'")
    )
  }
  if (!is.null(workers)) {
    DBI::dbExecute(
      conn = con,
      paste0("SET threads = ", workers)
    )
  }

  for (data_set in data_sets) {
    parquet_ds <- file.path(parquet_dir, data_set)
    if (file.exists(parquet_ds)) {
      warning(
        "Skipping '",
        data_set,
        "' - directory already exists at '",
        parquet_ds,
        "'. ",
        "Remove it manually to re-convert.",
        call. = FALSE
      )
      next
    }
    message("Processing ", data_set, " ...")
    if (data_set == "works") {
      message(
        "\n#####\nThis will take some hours. ",
        "Grab a coffee, have lunch, go home...\n#####"
      )
    }
    ds_start <- Sys.time()
    json_dir <- file.path(snapshot_dir, "data", data_set)

    # works needs maximum_object_size for large JSON records ----
    ndjson_options <- if (data_set == "works") {
      ", maximum_object_size=1000000000"
    } else {
      ""
    }

    paste0(
      "COPY ( ",
      "   SELECT * ",
      "   FROM read_ndjson('",
      json_dir,
      "/*/*.gz'",
      ndjson_options,
      ")",
      ") TO '",
      parquet_ds,
      "' ",
      "(FORMAT PARQUET, COMPRESSION SNAPPY, PER_THREAD_OUTPUT, ",
      "ROW_GROUP_SIZE 100_000, ROW_GROUPS_PER_FILE 20)"
    ) |>
      DBI::dbExecute(conn = con)

    message(
      "  done after ",
      round(difftime(Sys.time(), ds_start, units = "secs"), 2),
      " seconds"
    )
  }
}
