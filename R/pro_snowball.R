#' A function to perform a snowball search
#' and convert the result to a tibble/data frame.
#' @param identifier Character vector of openalex identifiers.
#' @param snowball parquet dataset; default: temporary directory.
#' @param partition The column which should be used to partition the table. Hive partitioning is used.
#' @param verbose Logical indicating whether to show a verbose information. Defaults to `FALSE`
#'
#' @return A list containing 2 elements:
#' - nodes: dataframe with publication records.
#' The last column `oa_input` indicates whether the work was
#' one of the input `identifier`(s).
#' - edges: publication link dataframe of 2 columns `from, to`
#' such that a row `A, B` means A -> B means A cites B.
#' In bibliometrics, the "citation action" comes from A to B.
#'
#' @export
#'
#' @importFrom openalexR oa_query
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#'
#' @md
#'
#' @examples
#' \dontrun{
#'
#' snowball_docs <- oa_snowball(
#'   identifier = c("W2741809807", "W2755950973"),
#'   citing_params = list(from_publication_date = "2022-01-01"),
#'   cited_by_params = list(),
#'   verbose = TRUE
#' )
#'
#' # Identical to above, but searches using paper DOIs
#' snowball_docs_doi <- oa_snowball(
#'   doi = c("10.1016/j.joi.2017.08.007", "10.7717/peerj.4375"),
#'   citing_params = list(from_publication_date = "2022-01-01"),
#'   cited_by_params = list(),
#'   verbose = TRUE
#' )
#' }
pro_snowball <- function(
    identifier = NULL,
    snowball = tempfile(fileext = ".snowball"),
    partition = NULL,
    verbose = FALSE) {
  snowball <- normalizePath(snowball, mustWork = FALSE)

  if (dir.exists(snowball)) {
    if (verbose) {
      message("Deleting and recreating `", snowball, "` to avoid inconsistencies.")
    }
    unlink(snowball, recursive = TRUE)
    dir.create(snowball, recursive = TRUE)
  }
  # fetching keypapers -----------------------------------------------------


  keypaper_json <- oa_query(
    openalex = identifier,
    entity = "works"
  ) |>
    pro_request(
      verbose = FALSE,
      json_dir = file.path(snowball, "keypaper_json")
    )

  keypaper_parquet <- json_to_parquet(
    json_dir = keypaper_json,
    corpus = file.path(snowball, "keypaper.parquet"),
    partition = NULL
  )

  keypaper <- read_corpus(
    corpus = keypaper_parquet,
    return_data = TRUE
  )


  # fetching documents citing the target keypapers (incoming - to: keypaper) ----


  if (verbose) {
    message("Collecting all documents citing the target keypapers (to = keypaper)...")
  }
  citing_json <- oa_query(
    cites = keypaper$id,
    entity = "works"
  ) |>
    pro_request(
      verbose = verbose,
      json_dir = file.path(snowball, "citing_json")
    )



  # fetching documents cited by the target keypapers (outgoing - from: keypaper )-----------------------


  if (verbose) message("Collecting all documents cited by the target keypapers (from = keypaper)...")
  cited_json <- oa_query(
    cited_by = keypaper$id,
    entity = "works"
  ) |>
    pro_request(
      verbose = verbose,
      json_dir = file.path(snowball, "cited_json")
    )


  # Assemble nodes and edges -----------------------------------------------

  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )


  # Create snowball using sql ---------------------------------------------


  system.file("pro_snowball.sql", package = "openalexPro") |>
    load_sql_file() |>
    gsub(pattern = "%%KEYPAPERS_JSON_DIR%%", replacement = keypaper_json) |>
    gsub(pattern = "%%CITED_JSON_DIR%%", replacement = cited_json) |>
    gsub(pattern = "%%CITING_JSON_DIR%%", replacement = citing_json) |>
    DBI::dbExecute(conn = con)


  # Create nodes.parquet ---------------------------------------------------


  paste0(
    "COPY ( ",
    "   SELECT DISTINCT ON(ID) ",
    "       * ",
    "   FROM ",
    "       nodes",
    ") TO '", file.path(snowball, "nodes.parquet"), "' ",
    "(FORMAT PARQUET, COMPRESSION SNAPPY",
    ifelse(
      is.null(partition),
      ")",
      paste0(", PARTITION_BY '", partition, "')")
    )
  ) |>
    DBI::dbExecute(conn = con)


  # Create edges.parquet ---------------------------------------------------


  paste0(
    "COPY ( ",
    "   SELECT DISTINCT ",
    "       * ",
    "   FROM ",
    "       edges",
    ") TO '", file.path(snowball, "edges.parquet"), "' ",
    "(FORMAT PARQUET, COMPRESSION SNAPPY, PARTITION_BY (from_source, to_source))"
  ) |>
    DBI::dbExecute(conn = con)

  # Return path to snowball ------------------------------------------------

  return(normalizePath(snowball))
}
