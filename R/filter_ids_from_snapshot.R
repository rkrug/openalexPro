#' Filter IDs from OA snapshot
#'
#' This function filters `ids` from an OA snapshot in parquet format (partitioned  by id_block is highly recommended)
#' and saves the results into the `arrow_dir` partitioned by `id_block`.
#'
#' @param corpus_dir The directory of the OA snapshot data.
#' @param ids either a `id_block` object or vector containing OpenAlex `ids` to filter.
#' @param arrow_dir The directory where the filtered IDs will be saved.
#'
#' @return The function returns the path to the directory where the filtered IDs were saved.
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#' @importFrom duckdb duckdb
#' @importFrom tictoc tic toc
#' @importFrom dplyr split
#'
#' @export
filter_ids_from_snapshot <- function(
    corpus_dir,
    ids,
    arrow_dir) {
  ###

  if (is.null(ids)) {
    stop("No `ids` specified!")
  }

  ###

  if (!inherits(ids, "id_block")) {
    ids <- id_block(ids)
  }
  ids <- base::split(ids, ids$id_block)

  ###

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = "~/tmp/temp.duckdb", read_only = FALSE)

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  ###

  message("OK. Let's go. This will take some time Grab a coffee, have lunch, go home...\nSee you tomorrow... ", toc(), "\n#####\n")
  lapply(
    ids,
    function(x) {
      message("  Extracting id_block ", x$id_block, " to parquet database in ", arrow_dir, " partitioned by id_blocks ...")
      id_block_dir <- file.path(arrow_dir, paste0("id_block=", x$id_block))
      tic()
      ##
      DBI::dbWriteTable(
        conn = con,
        name = "ids",
        value = ids
      )
      ##
      paste0(
        "COPY ( ",
        "   SELECT ",
        "       * ",
        "   FROM ",
        "       read_parquet('", id_block_dir, "/**/*.parquet') ",
        "   WHERE ",
        "       id IN (SELECT id FROM ids) ",
        "   ORDER BY id ",
        ") TO '", arrow_dir, "' ",
        "(FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY 'id_block')"
      ) |>
        DBI::dbExecute(conn = con)
      message("    done after ", toc())
    }
  )
  message("Nice to see you again. Did you have a nice rest? I was working for ", toc(), "\n#####\n")
  return(arrow_dir)
}
