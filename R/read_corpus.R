#' Read corpus from Parquet Dataset
#'
#' This function reads a corpus in Apache Parquet format and returns an Arrow
#' Dataset or a `tibble`.
#'
#' @param corpus The directory of the Parquet files.
#' @param return_data Logical indicating whether to return an Arrow Dataset
#'   (default) or a `tibble`.
#' @param comp_mode Compatibility mode with `openalexR` return values from  `openalexR::fetch( output = "tibble")` (default: `FALSE`).
#'   If `TRUE,`, the format of the returned values is identical to `openalexR::fetch( output = "tibble")`,
#'   if `FALSE`, the format may be functionally identical, but not structurally.
#'
#' @return An Arrow Dataset or a `tibble`.
#'
#' @md
#'
#' @importFrom arrow open_dataset
#' @importFrom dplyr collect
#'
#' @export
read_corpus <- function(
    corpus,
    return_data = FALSE,
    comp_mode = FALSE) {
  result <- arrow::open_dataset(corpus)
  if (comp_mode) {
    result <- result |>
      dplyr::mutate(
        citation = NULL,
        abstract_inverted_index = NULL,
      ) |>
      dplyr::rename(
        author = authorships
      )
  }
  if (return_data) {
    result <- dplyr::collect(result)
  }
  ##
  return(result)
}
