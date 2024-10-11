#' Read corpus from Parquet Dataset
#'
#' This function reads a corpus in Apache Parquet format and returns an Arrow
#' Dataset or a `tibble`.
#'
#' @param corpus The directory of the Parquet files.
#' @param return_data Logical indicating whether to return an Arrow Dataset
#'   (default) or a `tibble`.
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
    return_data = FALSE) {
  result <- arrow::open_dataset(corpus)
  if (return_data) {
    result <- dplyr::collect(result)
  }
  ##
  return(result)
}
