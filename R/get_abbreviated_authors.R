#' Abbreviate Authors
#'
#' This function abbreviates the author names in a given data frame of works.
#' The output is a list of author names in the format "First Author et al. (Year)" or "Author1 & Author2 (Year)".
#'
#' @param corpus The corpus. Either a character vector of length 1 with the path to a parquest dataset ot
#'   the corpus itself with the columns `id` and `publication_year` and `authorships`.
#'
#'
#' @return A vector of abbreviated author names and publication years.
#'
#' @importFrom dplyr select collect
#'
#' @export
#'
#'
#' @examples
#' \dontrun{
#' get_abbreviated_authors(corpus)
#' }
#'
get_abbreviated_authors <- function(
    corpus) {
  if (is.null(corpus)) {
    stop("No corpus specified!")
  }
  ##

  #   con <- DBI::dbConnect(duckdb::duckdb())

  #   on.exit(
  #     DBI::dbDisconnect(con, shutdown = TRUE)
  #   )

  #   corpus |>
  #     arrow::open_dataset() |>
  #     duckdb::duckdb_register_arrow(
  #       conn = con,
  #       name = "corpus"
  #     )

  #   authors_raw <- paste0(
  #     "      SELECT ",
  #     "          id,",
  #     "          publication_year,",
  #     "          authorships",
  #     "      FROM ",
  #     "          corpus"
  #   ) |>
  #     DBI::dbGetQuery(
  #       conn = con,
  #     )


  if (is.character(corpus)) {
    authors_raw <- arrow::open_dataset(corpus) |>
      dplyr::select(
        id,
        publication_year,
        authorships
      ) |>
      dplyr::collect()
  } else {
    authors_raw <- corpus
  }

  if (nrow(authors_raw) <= 1) {
    authors_abbr <- character(0)
  } else {
    authors_abbr <- lapply(
      seq_along(1:nrow(authors_raw)),
      function(i) {
        work <- authors_raw[i, ]
        if (nrow(work$authorships[[1]]) == 0) {
          abbr <- paste0("Unknown (", work$publication_year, ")")
        } else if (nrow(work$authorships[[1]]) <= 2) {
          abbr <- paste0(paste0(work$authorships[[1]]$author$display_name, collapse = " &"), " (", work$publication_year, ")")
        } else {
          abbr <- paste0(work$authorships[[1]]$author$display_name[1], " et.al (", work$publication_year, ")")
        }
      }
    ) |>
      unlist() |>
      gsub(pattern = "NULL AUTHOR_ID", replacement = "Unknown")
  }

  names(authors_abbr) <- authors_raw$id
  ###
  return(authors_abbr)
}
