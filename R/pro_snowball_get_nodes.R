#' A function to get the nodes for a snowball search
#' @param identifier Character vector of openalex identifiers.
#' @param doi Character vector of dois.
#' @param output_dir parquet dataset; default: temporary directory.
#' @param verbose Logical indicating whether to show a verbose information. Defaults to `FALSE`
#'
#' @return Path to the nodes parquet dataset
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
#'   identifier = c("W2741809807", "W2755950973"),
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
pro_snowball_get_nodes <- function(
  identifier = NULL,
  doi = NULL,
  output_dir = tempfile(fileext = ".snowball"),
  verbose = FALSE
) {
  if (!xor(is.null(identifier), is.null(doi))) {
    stop("Either `identifier` or `doi` needs to be specified!")
  }

  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  nodes <- file.path(output_dir, "nodes")

  if (dir.exists(nodes)) {
    if (verbose) {
      message(
        "Deleting and recreating `",
        nodes,
        "` to avoid inconsistencies."
      )
    }
    unlink(nodes, recursive = TRUE)
    dir.create(nodes, recursive = TRUE)
  }

  # Helper functions -------------------------------------------------------

  add_node_columns <- function(
    ds_path,
    oa_input,
    relation,
    nodes_dir = file.path(output_dir, "nodes")
  ) {
    open_dataset(ds_path) |>
      dplyr::mutate(
        oa_input = oa_input,
        relation = relation
      ) |>
      arrow::write_dataset(
        path = nodes_dir,
        format = "parquet",
        partitioning = "relation"
      )
    return(ds_path)
  }

  # fetching keypapers -----------------------------------------------------
  nodes_nn <- file.path(output_dir, "nodes_nn")

  if (verbose) {
    message("Collecting keypapers...")
  }

  keypaper_parquet <- ifelse(
    !is.null(identifier),
    oa_query(
      openalex = identifier,
      entity = "works"
    ),
    oa_query(
      doi = doi,
      entity = "works"
    )
  ) |>
    pro_request(
      verbose = verbose,
      output_dir = file.path(output_dir, "keypaper_json")
    ) |>
    pro_request_to_parquet(
      output_dir = file.path(output_dir, "keypaper_parquet")
    ) |>
    add_node_columns(
      oa_input = TRUE,
      relation = "keypaper",
      nodes = nodes_nn
    )

  keypaper <- read_corpus(
    corpus = keypaper_parquet,
    return_data = TRUE
  ) |>
    dplyr::select(
      id
    ) |>
    dplyr::collect()

  # fetching documents citing the target keypapers (incoming - to: keypaper) ----

  if (verbose) {
    message(
      "Collecting all documents citing the target keypapers (to = keypaper)..."
    )
  }

  citing_parquet <- oa_query(
    cites = keypaper$id,
    entity = "works"
  ) |>
    pro_request(
      verbose = verbose,
      output_dir = file.path(output_dir, "citing_json")
    ) |>
    pro_request_to_parquet(
      output_dir = file.path(output_dir, "citing_parquet")
    ) |>
    add_node_columns(
      oa_input = FALSE,
      relation = "citing",
      nodes = nodes_nn
    )

  # fetching documents cited by the keypapers (outgoing - from: keypaper )-----------------------

  if (verbose)
    message(
      "Collecting all documents cited by the target keypapers (from = keypaper)..."
    )

  cited_parquet <- oa_query(
    cited_by = keypaper$id,
    entity = "works"
  ) |>
    pro_request(
      verbose = verbose,
      output_dir = file.path(output_dir, "cited_json")
    ) |>
    pro_request_to_parquet(
      output_dir = file.path(output_dir, "cited_parquet")
    ) |>
    add_node_columns(
      oa_input = FALSE,
      relation = "cited",
      nodes = nodes_nn
    )

  # Normalize nodes --------------------------------------------------------

  normalize_parquet(
    input_dir = nodes_nn,
    output_dir = nodes,
    delete_input = FALSE
  )

  # Return path to snowball ------------------------------------------------

  return(normalizePath(nodes))
}
