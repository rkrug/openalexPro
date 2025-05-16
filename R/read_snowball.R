#' Read snowball from Parquet Dataset
#'
#' This function reads a snowball from Apache Parquet format and returns a list containing
#' nodes and edges, which can be either Arrow Datasets or `tibble`s.
#'
#' @param snowball The directory of the Parquet files as poppulater by `pro_snowball()`.
#' @param edge_type type of the returned edges. Possible values are:
#'    - **`core`**: only edges from or to the keypapers are selected
#'    - **`extended`**, only edges between the `nodes` are selected (this includes `core` edges)
#'    - **`outside`**: only  edges where either the `from` ot=r the `to` is not in `nodes`
#' multiple are allowed.
#' @param return_data Logical indicating whether to return an
#'   `ArrowObject` representing the corpus (default) or a
#'   `tibble` containing the whole corpus shou,d be returned.
#'
#' @return A list containing two elements: nodes and edges, which are either
#'   `ArrowObject` representing the corpus or `tibble`s containing the data.
#'
#' @md
#'
#' @importFrom dplyr filter select collect arrange desc
#'
#' @export
read_snowball <- function(
  snowball = NULL,
  edge_type = c("core", "extended", "outside"),
  return_data = FALSE,
  shorten_ids = TRUE
) {
  if (is.null(snowball)) {
    stop("Directory `snowball` missing!")
  }

  if (!dir.exists(snowball)) {
    stop("Directory `snowball` does not exist!")
  }

  edge_type <- match.arg(edge_type, several.ok = TRUE)

  # Nodes ------------------------------------------------------------------

  nodes <- read_corpus(
    corpus = file.path(snowball, "nodes"),
    return_data = FALSE
  ) |>
    dplyr::arrange(
      dplyr::desc(oa_input),
      id
    )

  if (shorten_ids) {
    nodes <- nodes |>
      dplyr::mutate(
        id = gsub("^https://openalex.org/", "", id)
      )
  }

  # Edges ------------------------------------------------------------------

  edges <- read_corpus(
    corpus = file.path(snowball, "edges"),
    return_data = FALSE
  ) |>
    dplyr::filter(
      edge_type %in% .env$edge_type
    ) |>
    dplyr::arrange(
      from,
      to
    )

  if (shorten_ids) {
    edges <- edges |>
      dplyr::mutate(
        from = gsub("^https://openalex.org/", "", from),
        to = gsub("^https://openalex.org/", "", to)
      )
  }

  # Collect or not ---------------------------------------------------------

  if (return_data) {
    nodes <- dplyr::collect(nodes)
    edges <- dplyr::collect(edges)
  }

  # Return -----------------------------------------------------------------

  return(
    list(
      nodes = nodes,
      edges = edges
    )
  )
}
