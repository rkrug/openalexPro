#' A function to get the nodes for a snowball search
#' @param identifier Character vector of openalex identifiers.
#' @param doi Character vector of dois.
#' @param output parquet dataset; default: temporary directory.
#' @param verbose Logical indicating whether to show a verbose information.
#'   Defaults to `FALSE`
#'
#' @return Path to the nodes parquet dataset
#'
#' @export
#'
#' @importFrom openalexR oa_query
#' @importFrom duckdb duckdb duckdb_register_arrow
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#' @importFrom arrow write_parquet
#'
#' @md
#'
pro_snowball_get_nodes <- function(
  identifier = NULL,
  doi = NULL,
  output = tempfile(fileext = ".snowball"),
  verbose = FALSE
) {
  if (!xor(is.null(identifier), is.null(doi))) {
    stop("Either `identifier` or `doi` needs to be specified!")
  }

  output <- normalizePath(output, mustWork = FALSE)

  if (dir.exists(output)) {
    if (verbose) {
      message(
        "Deleting and recreating `",
        output,
        "` to avoid inconsistencies."
      )
    }
    unlink(output, recursive = TRUE)
  }
  dir.create(output, recursive = TRUE)

  # Create and setup in memory DuckDB --------------------------------------

  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE),
    add = TRUE
  )
  paste0(
    "INSTALL json; LOAD json; "
  ) |>
    DBI::dbExecute(conn = con)

  # fetching keypapers -----------------------------------------------------

  if (verbose) {
    message("Collecting keypapers...")
  }

  ifelse(
    !is.null(identifier),
    oa_query(
      openalex = identifier,
      entity = "works"
    ),
    oa_query(
      doi = doi,
      entity = "works"
    )
  ) |>
    pro_request(
      output = file.path(output, "keypaper_json"),
      verbose = verbose,
      progress = verbose
    ) |>
    pro_request_jsonl(
      output = file.path(output, "keypaper_jsonl"),
      add_columns = list(
        oa_input = TRUE,
        relation = "keypaper"
      ),
      verbose = verbose
    ) |>
    pro_request_jsonl_parquet(
      output = file.path(output, "keypaper_parquet"),
      add_columns = list(
        oa_input = FALSE,
        relation = "citing"
      ),
      verbose = verbose
    )

  # Getting keypaper ids as returned by OpenAlex ---------------------------

  keypaper_ids <- sprintf(
    "
    SELECT
      id
    FROM 
      read_json_auto( '%s/*.json' )
    ",
    file.path(output, "keypaper_jsonl")
  ) |>
    DBI::dbGetQuery(conn = con) |>
    unlist() |>
    as.vector()

  # fetching documents citing the target keypapers (incoming - to: keypaper)
  # ----

  if (verbose) {
    message(
      "Collecting all documents citing the target keypapers (to = keypaper)..."
    )
  }

  oa_query(
    cites = keypaper_ids,
    entity = "works"
  ) |>
    pro_request(
      output = file.path(output, "citing_json"),
      verbose = verbose,
      progress = verbose
    ) |>
    pro_request_jsonl(
      output = file.path(output, "citing_jsonl"),
      add_columns = list(
        oa_input = FALSE,
        relation = "citing"
      ),
      verbose = verbose
    )

  # fetching documents cited by the keypapers (outgoing - from: keypaper
  # )-----------------------

  if (verbose) {
    message(
      "Collecting all documents cited by the target keypapers ..."
    )
  }

  cited_parquet <- oa_query(
    cited_by = keypaper_ids,
    entity = "works"
  ) |>
    pro_request(
      output = file.path(output, "cited_json"),
      verbose = verbose,
      progress = verbose
    ) |>
    pro_request_jsonl(
      output = file.path(output, "cited_jsonl"),
      add_columns = list(
        oa_input = FALSE,
        relation = "cited"
      ),
      verbose = verbose
    )

  # Combine individualparquet databases to nodes_parquet ----------------------

  sprintf(
    "
      COPY (
        SELECT 
          * REPLACE (CAST(oa_input AS BOOLEAN) AS oa_input)
        FROM 
        read_json_auto(
          ['%s', '%s','%s'],
          union_by_name = true
        )
      ) TO
        '%s'
        (FORMAT PARQUET, COMPRESSION SNAPPY, APPEND, PARTITION_BY 'relation')
      ",
    file.path(output, "keypaper_jsonl", "**", "*.json"),
    file.path(output, "cited_jsonl", "**", "*.json"),
    file.path(output, "citing_jsonl", "**", "*.json"),
    file.path(output, "nodes")
  ) |>
    DBI::dbExecute(conn = con)

  # Return path to nodes ------------------------------------------------

  return(normalizePath(file.path(output, "nodes")))
}
