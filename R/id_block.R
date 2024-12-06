#' Create a table with id blocks
#'
#' This function takes a vector of OpenAlex `ids`, and determines the
#'   - short_id
#'   - long_id
#'   - id_block
#' @param ids A vector of IDs
#'
#' @return A tibble with additional class `id_block` with the columns 'id`, `long_id`, `short_id` and `id_block`.
#'
#' @importFrom tibble as_tibble
#' @importFrom dplyr mutate rename
#'
#' @md
#' @export
#' @examples
#' id_block(ids = c("https://openalex.org/W2582743722", "W2582756"))
#'
id_block <- function(
    ids = NULL) {
  if (inherits(ids, "id_block")) {
    warning("Input is already of class 'id_block'")
    return(ids)
  }
  ###
  if (is.null(ids)) {
    ids <- tibble::as_tibble(
      data.frame(
        id = character(),
        long_id = character(),
        short_id = character(),
        id_block = numeric(),
        stringsAsFactors = FALSE
      )
    )
  } else {
    ids <- ids |>
      tibble::as_tibble() |>
      dplyr::rename(
        id = value
      ) |>
      dplyr::mutate(
        short_id = gsub(
          pattern = "https://openalex.org/",
          replacement = "",
          x = id
        ),
        long_id = paste0(
          "https://openalex.org/",
          short_id
        ),
        id_block = gsub(
          pattern = "W",
          replacement = "",
          x = short_id
        ) |>
          as.numeric()
      ) |>
      dplyr::mutate(
        id_block = id_block %/% 10000
      )
  }
  ###
  class(ids) <- append(class(ids), "id_block")
  ###
  return(ids)
}
