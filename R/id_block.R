#' Compute ID block from OpenAlex IDs
#'
#' This function computes the ID block partition key from OpenAlex IDs.
#' The ID block is calculated as the trailing numeric portion of the ID
#' divided by 10,000.
#'
#' @param ids Character vector of OpenAlex IDs in any format:
#'   - Short form: `"W2741809807"`
#'   - Long form: `"https://openalex.org/W2741809807"`
#'   - Path-based: `"https://openalex.org/domains/2"`
#'
#' @return Integer vector of ID blocks.
#'
#' @details
#' OpenAlex IDs come in several formats:
#' - Standard: `https://openalex.org/{type}{number}` (e.g., `W1234567890`)
#' - Path-based: `https://openalex.org/{entity_type}/{number}` (e.g., `domains/2`, `subfields/2208`)
#'
#' The ID block is computed as `floor(number / 10000)`, where `number` is
#' the trailing numeric portion of the ID. This groups approximately 10,000
#' IDs into each block, useful for partitioning large datasets.
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
#' # Path-based IDs
#' id_block("https://openalex.org/domains/2")
#' # Returns: 0
#'
#' # Works with any entity type
#' id_block(c("A123456789", "I987654321"))
#' # Returns: c(12345, 98765)
#'
#' @export
#' @md
id_block <- function(ids) {
  ## Extract trailing numeric portion from any ID format
  numeric_part <- as.numeric(sub(".*?(\\d+)$", "\\1", ids))

  ## Compute block (integer division by 10000)
  as.integer(floor(numeric_part / 10000))
}
