#' A function to extract the edges from a parquet database containing the nodes
#'
#' @param nodes Path to the nodes parquet dataset
#' @param output output folder, in which the parquet database containing the
#'   edges called `edges` will be savedp default: temporary directory.
#' @param verbose Logical indicating whether to show a verbose information.
#'   Defaults to `FALSE`
#'
#' @return A list containing 2 elements:
#' - nodes: dataframe with publication records.
#' The last column `oa_input` indicates whether the work was one of the input
#'   `identifier`(s).
#' - edges: publication link dataframe of 2 columns `from, to`
#' such that a row `A, B` means A -> B means A cites B. In bibliometrics, the
#'   "citation action" comes from A to B.
#'
#' @export
#'
#' @importFrom openalexR oa_query
#' @importFrom duckdb duckdb duckdb_register_arrow
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#' @importFrom arrow write_parquet
#'
#' @md
#'
pro_snowball_extract_edges <- function(
  nodes = NULL,
  output = tempfile(fileext = ".snowball"),
  verbose = FALSE
) {
  output <- normalizePath(output, mustWork = FALSE)

  edges <- file.path(output, "edges")

  if (file.exists(edges)) {
    if (verbose) {
      message(
        "Deleting and recreating `",
        edges,
        "` to avoid inconsistencies."
      )
    }
    unlink(edges, recursive = TRUE)
    dir.create(edges, recursive = TRUE)
  }

  # Extract Edges -------------------------------------------------

  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  arrow::open_dataset(nodes) |>
    duckdb::duckdb_register_arrow(
      conn = con,
      name = "nodes"
    )

  system.file("extract_edges.sql", package = "openalexPro2") |>
    load_sql_file() |>
    DBI::dbExecute(conn = con)

  # Create edges ---------------------------------------------------

  paste0(
    "COPY ( ",
    "   SELECT DISTINCT ",
    "       * ",
    "   FROM ",
    "       edges",
    ") TO '",
    edges,
    "' ",
    "(FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY (edge_type))"
  ) |>
    DBI::dbExecute(conn = con)

  # Return path to snowball ------------------------------------------------

  return(normalizePath(output))
}
