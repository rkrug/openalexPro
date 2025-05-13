#' Read snowball from Parquet Dataset
#'
#' This function reads a snowball from Apache Parquet format and returns a list containing
#' nodes and edges, which can be either Arrow Datasets or `tibble`s.
#'
#' @param snowball The directory of the Parquet files as poppulater by `pro_snowball()`.
#' @param edge_type description
#' @param return_data Logical indicating whether to return an
#'   `ArrowObject` representing the corpus (default) or a
#'   `tibble` containing the whole corpus shou,d be returned.
#'
#' @return A list containing two elements: nodes and edges, which are either
#'   `ArrowObject` representing the corpus or `tibble`s containing the data.
#'
#' @md
#'
#' @importFrom dplyr filter select collect
#'
#' @export
read_snowball <- function(
  snowball = NULL,
  edge_type = c("core", "extended"),
  return_data = FALSE
) {
  if (is.null(snowball)) {
    stop("Directory `snowball` missing!")
  }

  if (!dir.exists(snowball)) {
    stop("Directory `snowball` does not exist!")
  }

  edge_type <- match.arg(edge_type)

  nodes <- read_corpus(
    corpus = file.path(snowball, "nodes"),
    return_data = FALSE
  )

  edges <- read_corpus(
    corpus = file.path(snowball, "edges"),
    return_data = FALSE
  ) |>
    dplyr::filter(
      edge_type == edge_type
    )

  if (return_data) {
    nodes <- dplyr::collect(nodes)
    edges <- dplyr::collect(edges)
  }

  return(
    list(
      nodes = nodes,
      edges = edges
    )
  )
}
