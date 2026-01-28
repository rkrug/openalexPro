#' Compute ID block from OpenAlex IDs
#'
#' This function computes the ID block partition key from OpenAlex IDs.
#' The ID block is calculated as the numeric portion of the ID divided by 10,000.
#'
#' @param ids Character vector of OpenAlex IDs (e.g., "W2741809807" or
#'   "https://openalex.org/W2741809807").
#'
#' @return Integer vector of ID blocks.
#'
#' @details
#' OpenAlex IDs have the format `https://openalex.org/{type}{number}` where
#' `{type}` is a single letter (W for works, A for authors, etc.) and
#' `{number}` is a numeric identifier.
#'
#' The ID block is computed as `floor(number / 10000)`, which groups
#' approximately 10,000 IDs into each block. This is useful for partitioning
#' large datasets.
#'
#' @examples
#' # Short form IDs
#' id_block(c("W2741809807", "W2741809808", "W1234567890"))
#' # Returns: c(274180, 274180, 123456)
#'
#' # Long form IDs
#' id_block("https://openalex.org/W2741809807")
#' # Returns: 274180
#'
#' # Works with any entity type
#' id_block(c("A123456789", "I987654321"))
#' # Returns: c(12345, 98765)
#'
#' @export
#' @md
id_block <- function(ids) {
  ## Remove URL prefix if present
  ids_clean <- sub("^https://openalex.org/", "", ids)

  ## Extract numeric portion (remove first character which is the type letter)
  numeric_part <- as.numeric(substr(ids_clean, 2, nchar(ids_clean)))

  ## Compute block (integer division by 10000)
  as.integer(floor(numeric_part / 10000))
}
