#' Convert OA snapshot to Arrow format
#'
#' This function converts the OA (openalex) snapshot data to Arrow format.
#' Existing datasets are skipped with a warning.
#'
#' @param snapshot_dir The directory path of the OA snapshot data. Default is "Volumes/openalex/openalex-snapshot".
#' @param arrow_dir The directory path where the Arrow files will be saved. Default is "Volumes/openalex/arrow".
#' @param data_sets A character vector specifying the data sets to process. Default is NULL, which processes all data sets.
#' @param temp_directory location of the temporaty directory for duckdb. Initial runs indicate
#'   that 2TB should be safe. Default is `NULL`, use the system temporary directory.
#' @param memory_limit DuckDB memory limit (e.g., "64GB"). Set to 50-60% of
#'   system RAM for optimal performance. Default is `NULL`, use DuckDB default.
#' @param threads Number of threads for DuckDB to use. Lower values reduce memory
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
  arrow_dir = file.path("", "Volumes", "openalex", "arrow"),
  data_sets = NULL,
  temp_directory = NULL,
  memory_limit = NULL,
  threads = NULL
) {
  if (is.null(data_sets)) {
    data_sets <- list.dirs(
      file.path(snapshot_dir, "data"),
      recursive = FALSE,
      full.names = FALSE
    )
    ## Remove merged_dirs
    data_sets <- data_sets[data_sets != "merged_ids"]
  }

  dir.create(arrow_dir, recursive = TRUE, showWarnings = FALSE)

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
  if (!is.null(threads)) {
    DBI::dbExecute(
      conn = con,
      paste0("SET threads = ", threads)
    )
  }

  for (data_set in data_sets) {
    arrow_ds <- file.path(arrow_dir, data_set)
    if (file.exists(arrow_ds)) {
      warning(
        "Skipping '", data_set, "' - directory already exists at '", arrow_ds, "'. ",
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

    ## works needs maximum_object_size for large JSON records
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
      arrow_ds,
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
