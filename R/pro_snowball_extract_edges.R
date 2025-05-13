#' A function to extract the edges from a parquet database containing the nodes
#'
#' @param identifier Character vector of openalex identifiers.
#' @param doi Character vector of dois.
#' @param output_dir parquet dataset; default: temporary directory.
#' @param partition The column which should be used to partition the datasets usoing hive partitioning.
#' @param verbose Logical indicating whether to show a verbose information. Defaults to `FALSE`
#'
#' @return A list containing 2 elements:
#' - nodes: dataframe with publication records.
#' The last column `oa_input` indicates whether the work was
#' one of the input `identifier`(s).
#' - edges: publication link dataframe of 2 columns `from, to`
#' such that a row `A, B` means A -> B means A cites B.
#' In bibliometrics, the "citation action" comes from A to B.
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
#' @examples
#' \dontrun{
#'
#' snowball_docs <- pro_snowball(
#'    = c("W2741809807", "W2755950973"),
#'   citing_params = list(from_publication_date = "2022-01-01"),
#'   cited_by_params = list(),
#'   verbose = TRUE
#' )
#'
#' # Identical to above, but searches using paper DOIs
#' snowball_docs_doi <- oa_snowball(
#'   doi = c("10.1016/j.joi.2017.08.007", "10.7717/peerj.4375"),
#'   citing_params = list(from_publication_date = "2022-01-01"),
#'   cited_by_params = list(),
#'   verbose = TRUE
#' )
#' }
pro_snowball_extract_edges <- function(
  nodes = NULL,
  output_dir = tempfile(fileext = ".snowball"),
  partition = NULL,
  verbose = FALSE
) {
  output_dir <- normalizePath(output_dir, mustWork = FALSE)

  edges <- file.path(output_dir, "edges")

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

  system.file("extract_edges.sql", package = "openalexPro") |>
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

  return(normalizePath(output_dir))
}
