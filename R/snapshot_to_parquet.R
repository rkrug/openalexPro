#' Convert OA snapshot to Arrow format
#'
#' This function converts the OA (openalex) snapshot data to Arrow format.
#'
#' @param snapshot_dir The directory path of the OA snapshot data. Default is "Volumes/openalex/openalex-snapshot".
#' @param arrow_dir The directory path where the Arrow files will be saved. Default is "Volumes/openalex/arrow".
#' @param data_sets A character vector specifying the data sets to process. Default is NULL, which processes all data sets.
#' @param overwrite If `TRUE` the existing Arrow files will be overwritten. Default is `FALSE`.
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#' @importFrom duckdb duckdb
#'
#' @examples
#' \dontrun{
#' # Convert all data sets in the default snapshot directory
#' oa_snapshot_to_parquet()
#'
#' # Convert specific data sets in a custom snapshot directory
#' oa_snapshot_to_parquet(snapshot_dir = "/path/to/snapshot", data_sets = c("data_set1", "data_set2"))
#' }
#'
#' @export
#' @md
snapshot_to_parquet <- function(
    snapshot_dir = file.path("", "Volumes", "openalex", "openalex-snapshot"),
    arrow_dir = file.path("", "Volumes", "openalex", "arrow"),
    data_sets = NULL,
    overwrite = FALSE) {
  if (is.null(data_sets)) {
    data_sets <- list.dirs(file.path(snapshot_dir, "data"), recursive = FALSE, full.names = FALSE)
    ## Remove merged_dirs
    data_sets <- data_sets[data_sets != "merged_ids"]
  }

  dir.create(arrow_dir, recursive = TRUE, showWarnings = FALSE)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = "~/tmp/temp.duckdb", read_only = FALSE)

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  paste0(
    "INSTALL json"
  ) |>
    DBI::dbExecute(conn = con)

  paste0(
    "LOAD json"
  ) |>
    DBI::dbExecute(conn = con)

  ## everything except of works
  for (data_set in data_sets[data_sets != "works"]) {
    arrow_ds <- file.path(arrow_dir, data_set)
    if (file.exists(arrow_ds)) {
      if (overwrite) {
        unlink(arrow_ds, recursive = TRUE)
      } else {
        message("Skipping ", data_set, " ...")
        next
      }
    }
    message("Processing ", data_set, " ...")
    json_dir <- file.path(snapshot_dir, "data", data_set)
    paste0(
      "COPY ( ",
      "   SELECT ",
      "       * ",
      "   FROM ",
      "       read_ndjson('", json_dir, "/*/*.gz')",
      ") TO '", arrow_ds, "' ",
      "(FORMAT PARQUET, COMPRESSION SNAPPY)"
    ) |>
      DBI::dbExecute(conn = con)
  }

  ## works
  if ("works" %in% data_sets) {
    data_set <- "works"
    arrow_ds <- file.path(arrow_dir, data_set)
    if (file.exists(arrow_ds)) {
      if (overwrite) {
        unlink(arrow_ds, recursive = TRUE)
      } else {
        message("Skipping ", data_set, " ...")
        next
      }
    }
    message("Processing ", data_set, " ...")
    json_dir <- file.path(snapshot_dir, "data", data_set)
    paste0(
      "COPY ( ",
      "   SELECT ",
      "       SUBSTR(id, 23)::bigint // 10000  AS id_block, ",
      "       * ",
      "   FROM ",
      "       read_ndjson('", json_dir, "/*/*.gz', maximum_object_size=1000000000)",
      ") TO '", arrow_ds, "' ",
      "(FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY 'publication_year')"
    ) |>
      DBI::dbExecute(conn = con)
  }
}
