#' Extract authors' institution country codes
#'
#' This function extracts the institution country codes of authors from given corpus in `parquet` format.
#'
#' @param corpus the corpus in parquet format
#' @param corpus_authors parquet dataset of the result. If `partition` is `NULL', a file, otherwise a directorty.
#' @param partition The column which should be used to partition the table. Hive partitioning is used.
#'   Set to NULL to not partition the table.

#'
#' @return Fully qualified path to the resulting parquet dataset.
#'
#' @export
#'
#' @importFrom arrow open_dataset
#' @importFrom duckdb duckdb duckdb_register_arrow
#'
#' @examples
#' \dontrun{
#' authors <- data.frame(
#'   institution_country_code = c("US", "UK", "DE"),
#'   stringsAsFactors = FALSE
#' )
#' extract_authors(authors)
#' }
#'
#' @md

extract_authors <- function(
    corpus,
    corpus_authors = "corpus_authors",
    partition = "country") {
  ## Check if corpusr is specified
  if (is.null(corpus)) {
    stop("No corpus specified!")
  }

  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  corpus |>
    arrow::open_dataset() |>
    duckdb::duckdb_register_arrow(
      conn = con,
      name = "corpus"
    )

  result <- paste0(
    "COPY ( ",
    "   SELECT ",
    "       id AS work_id, ",
    "       publication_year,",
    "       author_position, ",
    "       UNNEST(author), ",
    "       UNNEST(countries) AS country ",
    "   FROM ",
    "   (",
    "      SELECT ",
    "          id,",
    "          publication_year,",
    "          UNNEST(authorships, max_depth := 2)",
    "      FROM ",
    "          corpus",
    "   )",
    ") TO '", corpus_authors, "' ",
    "(FORMAT PARQUET, COMPRESSION SNAPPY",
    ifelse(
      is.null(partition),
      ")",
      paste0(", PARTITION_BY '", partition, "')")
    )
  ) |>
    DBI::dbSendQuery(
      conn = con,
    )

  ###

  return(normalizePath(corpus_authors))
}
