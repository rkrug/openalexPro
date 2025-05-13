#' Read corpus from Parquet Dataset
#'
#' This function reads a corpus in Apache Parquet format and returns an
#' `ArrowObject` representing the corpus which can be fed into a `dplyr` pipeline
#' or a `tibble` which contains all the data.
#'
#' @param corpus The directory of the Parquet files.
#' @param return_data Logical indicating whether to return an
#'   `ArrowObject` representing the corpus (default) or a
#'   `tibble` containing the whole corpus shou,d be returned.
#'
#' @return An `ArrowObject` representing the corpus or a `tibble`.
#'
#' @md
#'
#' @importFrom arrow open_dataset
#' @importFrom dplyr collect
#'
#' @export
read_corpus <- function(
  corpus,
  return_data = FALSE
) {
  result <- arrow::open_dataset(corpus)
  ##
  if (return_data) {
    result <- dplyr::collect(result)
  }
  ##
  return(result)
}
