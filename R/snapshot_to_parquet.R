#' Convert OA snapshot to Arrow format
#'
#' This function converts the OA (openalex) snapshot data to Arrow format.
#'
#' @param snapshot_dir The directory path of the OA snapshot data. Default is "Volumes/openalex/openalex-snapshot".
#' @param arrow_dir The directory path where the Arrow files will be saved. Default is "Volumes/openalex/arrow".
#' @param data_sets A character vector specifying the data sets to process. Default is NULL, which processes all data sets.
#' @param overwrite If `TRUE` the existing Arrow files will be overwritten. Default is `FALSE`.
#' @param temp_directory location of the temporaty directory for duckdb. Initial runs indicate
#'   that 2TB should be safe. Default is `NULL`, use the system temporary directory.
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#' @importFrom duckdb duckdb
#' @importFrom tictoc tic toc
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
    overwrite = FALSE,
    temp_directory = NULL) {
  if (is.null(data_sets)) {
    data_sets <- list.dirs(file.path(snapshot_dir, "data"), recursive = FALSE, full.names = FALSE)
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
    DBI::dbExecute(conn = con, paste0("set temp_directory='", temp_directory, "'"))
  }
  # DBI::dbExecute(conn = con, paste0("set temp_directory='", arrow_dir, "'"))
  # DBI::dbExecute(conn = con, "PRAGMA max_temp_directory_size='50GiB'")

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
        return()
      }
    }
    message("Processing ", data_set, " ...")
    json_dir <- file.path(snapshot_dir, "data", data_set)
    ###
    message("\n#####\nThe following steps will take some hours. Grab a coffee, have lunch, go home...\nSee you tomorrow...")
    ###
    tic()
    tic()
    message("  1 of 2: Converting ", json_dir, " to parquet database in ", arrow_ds, "...")
    paste0(
      "COPY ( ",
      "   SELECT ",
      "       SUBSTR(id, 23)::bigint // 10000  AS id_block, ",
      "       * ",
      "   FROM ",
      "       read_ndjson('", json_dir, "/*/*.gz', maximum_object_size=1000000000)",
      ") TO '", arrow_ds, "' ",
      "(FORMAT PARQUET, COMPRESSION SNAPPY, PER_THREAD_OUTPUT, ROW_GROUP_SIZE 100_000, ROW_GROUPS_PER_FILE 50)"
    ) |>
      DBI::dbExecute(conn = con)
    message("    done after ", toc(), " and to the next one ...")
    ###
    arrow_ds_id_block <- paste0(arrow_ds, "_id_block")
    unlink(arrow_ds_id_block, recursive = TRUE)
    message("  2 of 2: Converting ", arrow_ds, " to parquet database in ", arrow_ds_id_block, " partitioned by id blocks of maximum 10'000 ids...")
    tic()
    pqfs <- list.files(arrow_ds, full.names = TRUE)
    # id_blocks <- DBI::dbGetQuery(con, paste0("SELECT id_block, COUNT(id_block) AS count FROM read_parquet('", arrow_ds, "/**/*.parquet') GROUP BY id_block ORDER BY id_block"))
    for (i in 1:length(pqf)) {
      message("     Converting ", i, " of ", length(pqf), " to parquet database in ", arrow_ds_id_block, " partitioned by id blocks of maximum 10'000 ids...")
      tic()
      paste0(
        "CREATE TEMPORARY TABLE temp AS ",
        "   SELECT ",
        "       * ",
        "   FROM ",
        "       read_parquet('", pqfs[i], "') ",
        "   ORDER BY id "
      ) |>
        DBI::dbExecute(conn = con)
      paste0(
        "COPY ",
        "   temp ",
        "TO '", arrow_ds_id_block, "' ",
        "(FORMAT PARQUET, APPEND, COMPRESSION SNAPPY, PARTITION_BY 'id_block')"
      ) |>
        DBI::dbExecute(conn = con)
      toc()
    }
    message("    done after ", toc())
    message("Nice to see you again. Did you have a nice rest? I was working for ", toc(), "\n#####\n")
  }
}
