#' Get abstracts from corpus
#'
#' This function takes a corpus and returns a named vector with the abstracts of the works.
#' The abstracts are constructed from the abstract inverted index.
#'
#' @param corpus The corpus. Either a character vector of length 1 with the path to a parquest dataset ot the corpus itself with the columns `id` and `abstract_inverted_index`.
#'
#' @importFrom dplyr select collect
#' @importFrom arrow open_dataset
#'
#' @return A named vector with the abstracts of the works.
#' @export
get_abstract <- function(
    corpus) {
  if (is.null(corpus)) {
    stop("No corpus specified!")
  }
  ##

  # con <- DBI::dbConnect(duckdb::duckdb())

  # on.exit(
  #   DBI::dbDisconnect(con, shutdown = TRUE)
  # )

  # corpus |>
  #   arrow::open_dataset() |>
  #   duckdb::duckdb_register_arrow(
  #     conn = con,
  #     name = "corpus"
  #   )

  # abstracts <- paste0(
  #   "   SELECT ",
  #   "       id, ",
  #   "       UNNEST(abstract_inverted_index)",
  #   "   FROM ",
  #   "   (",
  #   "      SELECT ",
  #   "          id,",
  #   "          abstract_inverted_index",
  #   "      FROM ",
  #   "          corpus",
  #   "   )"
  # ) |>
  #   DBI::dbGetQuery(
  #     conn = con,
  #   ) |>
  #   tibble::as_tibble()

  aii_2_ab <- function(abstract_inverted_index) {
    w <- rep(
      abstract_inverted_index$key,
      lengths(abstract_inverted_index$value)
    )
    ind <- unlist(abstract_inverted_index$value)

    if (is.null(ind)) {
      ab <- ""
    } else {
      ab <- paste(w[order(ind)], collapse = " ", sep = "")
    }
    return(ab)
  }


  if (is.character(corpus)) {
    abstracts <- arrow::open_dataset(corpus) |>
      dplyr::select(
        id,
        abstract_inverted_index
      ) |>
      dplyr::collect()
  } else {
    abstracts <- corpus
  }

  result <- sapply(
    abstracts$abstract_inverted_index,
    aii_2_ab
  )
  names(result) <- abstracts$id

  ###
  return(result)
}
