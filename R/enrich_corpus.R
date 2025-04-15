#' Convert JSON files to Apache Parquet files
#'
#' The function takes a directory of JSON files as written from a call to `pro_request(..., corpus = "FOLDER")`
#' and converts it to a Apache Parquet dataset partitiond by the page.
#'
#' @param corpus The directory of JSON files returned from `pro_request(..., json_dir = "FOLDER")`.
#' @param corpus_enriched parquet dataset; default: temporary directory.
#' @param verbose Logical indicating whether to show a verbose information. Defaults to `FALSE`
#' @return The function does not return anything, but it creates a directory with
#'   Apache Parquet files.
#' @param delete_input Determines if the `corpus` should be deleted afterwards. Defaults to `FALSE`.
#'
#' @details The function uses DuckDB to read the JSON files and to create the
#'   Apache Parquet files. The function creates a DuckDB connection in memory and
#'   readsds the JSON files into DuckDB when needed. Then it creates a SQL query to convert the
#'   JSON files to Apache Parquet files and to copy the result to the specified
#'   directory.
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#'
#' @md
#'
#' @examples
#' \dontrun{
#' source_to_parquet(corpus = "corpus", corpus_enriched = "corpus_enriched")
#' }
#' @export

enrich_corpus <- function(
  corpus = NULL,
  corpus_enriched = NULL,
  verbose = FALSE,
  delete_input = FALSE
) {
  ## Check if corpus is specified
  if (is.null(corpus)) {
    stop("No corpus to enrich specified!")
  }

  if (is.null(corpus_enriched)) {
    corpus_enriched <- corpus
    if (verbose) {
      message(
        "No enriched corpus specified, replacing in corpus ",
        corpus_enriched
      )
    }
  }

  ## Define set of parquet files
  parquets <- list.files(
    corpus,
    pattern = "*.parquet$",
    recursive = TRUE,
    full.names = TRUE
  )

  ## Create in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  # paste0(
  #   "INSTALL json; LOAD json; "
  # ) |>
  #   DBI::dbExecute(conn = con)

  for (i in seq_along(parquets)) {
    fn <- parquets[i]
    fn_out <- file.path(
      corpus_enriched,
      gsub(pattern = ".parquet$", replace = "_enr.parquet", basename(fn))
    )

    if (verbose) {
      message("Converting ", i, " of ", length(parquets), " : ", fn)
    }

    pn <- basename(fn) |>
      gsub(pattern = ".json|page_", replacement = "")

    paste0(
      "COPY ( ",
      "  SELECT",
      "      *,",
      ## Expand abstract",
      "      list_aggregate(",
      "          map_keys(abstract_inverted_index),",
      "         'string_agg',",
      "          ' '",
      "      ) as abstract,",
      ## Create short citations",
      "      CASE",
      "          WHEN len(authorships) = 1 THEN authorships [1].author.display_name || ' (' || publication_year || ')'",
      "          WHEN len(authorships) = 2 THEN authorships [1].author.display_name || ' & ' || authorships [2].author.display_name || ' (' || publication_year || ')'",
      "          WHEN len(authorships) > 2 THEN authorships [1].author.display_name || ' et al.' || ' (' || publication_year || ')'",
      "      END AS citation",
      "  FROM read_parquet('",
      fn,
      "')",
      ") TO '",
      fn_out,
      "' ",
      "(FORMAT PARQUET, COMPRESSION SNAPPY, APPEND);"
    ) |>
      DBI::dbExecute(conn = con)

    if (corpus == corpus_enriched) {
      unlink(fn)
    }
  }
  if (delete_input) {
    unlink(corpus, recursive = TRUE, force = TRUE)
  }

  return(normalizePath(corpus_enriched))
}
