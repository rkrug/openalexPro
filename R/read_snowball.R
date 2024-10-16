#' Read snowball from Parquet Dataset
#'
#' This function reads a snowball from Apache Parquet format and returns a list containing
#' nodes and edges, which can be either Arrow Datasets or `tibble`s.
#'
#' @param snowball The directory of the Parquet files as poppulater by `pro_snowball()`.
#' @param return_data Logical indicating whether to return Arrow Datasets (`FALSE`, default)
#'   or `tibble`s.
#' @param comp_mode Compatibility mode with `openalexR::oa_snowball()`. If `TRUE`, the
#'   format of the returned values is identical to the return value from `openalexR::oa_snowball()`,
#'   if `FALSE`, the nodes are in the format as downloaded from `openalexRro::pro_snowball()`. `edges
#'   contains all edges from the snowball, including citations between the identified paper as well as
#'   citations of papers not included in `nodes`. `edges` also contains two additional columns, namely
#'   `source_from` and `source_to`, indicating if the id in the `from`` or `to` respectively are from a
#'   `"keypaper"`, `"nodes"` or `"oa"`, i.e. not in nodes.
#'   Defaults to `FALSE`.
#'
#' @return A list containing two elements: nodes and edges, which are either Arrow Datasets or `tibble`s.
#'
#' @md
#'
#' @importFrom dplyr filter select collect
#'
#' @export
read_snowball <- function(
    snowball,
    return_data = FALSE,
    comp_mode = FALSE) {
  nodes <- read_corpus(
    corpus = file.path(snowball, "nodes.parquet"),
    return_data = return_data,
    comp_mode = comp_mode
  )

  edges <- read_corpus(
    corpus = file.path(snowball, "edges.parquet"),
    return_data = FALSE,
    comp_mode = FALSE
  )

  if (comp_mode) {
    edges <- edges |>
      dplyr::filter(
        from_source != "oa",
        to_source != "oa",
        from_source == "keypaper" | to_source == "keypaper"
      ) |>
      dplyr::select(
        -from_source,
        -to_source
      )
  }

  if (return_data) {
    edges <- collect(edges)
  }

  return(
    list(
      nodes = nodes,
      edges = edges
    )
  )
}
