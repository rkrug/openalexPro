#' Convert JSON files to Apache Parquet files
#'
#' The function takes a directory of JSON files as written from a call to `oa_request(..., json_dir = "FOLDER")`
#'  and converts it to a Apache Parquet dataset.
#'
#' @param json_dir The directory of JSON files returned from `oa_request(..., json_dir = "FOLDER")`.
#' @param corpus parquet dataset. If `partition` is `NULL', a file, otherwise a directorty.
#' @param partition The column which should be used to partition the table. Hive partitioning is used.
#'   Set to NULL to not partition the table.
#'
#' @return The function does not return anything, but it creates a directory with
#'   Apache Parquet files.
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
#' json_to_parquet(json_dir = "json", corpus = "arrow")
#' }
#' @export
json_to_parquet_duckdb <- function(
    json_dir = system.file("json_1000", package = "openalexPro"),
    corpus = "corpus",
    partition = "publication_year") {
  ## Check if json_dir is specified
  if (is.null(json_dir)) {
    stop("No json_dir specified!")
  }

  ## Define set of json files

  ## Create in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  ## Install and load json
  paste0(
    "INSTALL json"
  ) |>
    DBI::dbExecute(conn = con)

  paste0(
    "LOAD json"
  ) |>
    DBI::dbExecute(conn = con)


  paste0(
    # "COPY ( ",
    "   SELECT ",
    "       *, ",
    "       UNLIST(",
    "          json_extract_string(abstract_inverted_index, '$.*'))::integer[] AS aii, ",
    "          json_keys(abstract_inverted_index) AS keys) ",
    "          SELECT ",
    "            unnest(aii) as i, ",
    "            array_extract(keys, i) AS t order by i asc) ",
    "          SELECT ",
    "           string_agg(t, ' '",
    "       ) AS abs_aii",
    "       array_to_string(abstract_inverted_index, ' ') AS abstract",
    "   FROM (",
    "       SELECT ",
    "           UNNEST(results,  max_depth := 2) ",
    "       FROM ",
    "           read_json_auto('", json_dir, "/*.json')",
    "       )" # ,
    #   "    ) TO '", corpus, "' ",
    #   "(FORMAT PARQUET, COMPRESSION SNAPPY",
    #   ifelse(
    #     is.null(partition),
    #     ")",
    #     paste0(", PARTITION_BY '", partition, "')")
    #   )
  ) |>
    DBI::dbGetQuery(conn = con)

  return(normalizePath(corpus))
}


## rogerwilco, duckdb discord, sql channel, 24th September 2024

###### 14:05:

# A start could be something like this with some additional cleaning maybe?

# ```sql
# from read_json_auto('https://api.openalex.org/works/W2741809807', ignore_errors = true)
# select id, array_to_string(json_keys(abstract_inverted_index), ' ') as aii_abs;
# ```
# What is the code for the conversion made in R currently?

# from (
#   from (
#     from read_json_auto('https://api.openalex.org/works/W2741809807', ignore_errors = true)
#     select id, unlist(json_extract_string(abstract_inverted_index, '$.*'))::integer[] as aii,
#     json_keys(abstract_inverted_index) as keys
#   )
#   select
#     unnest(aii) as i,
#     array_extract(keys, i) as t order by i asc
# )
# select string_agg(t, ' ') as abs_aii;

###### 17:12:

# Inverting the abstract inverted index it looks like you can not get a "lossless" variant back since certain stopwords are removed (I think). Currently this is where I give up (and I'm not sure about what causes the ndjson difference visavi the json directly provided from the API that you are running into):

# ```sql
#   from (from (from read_json_auto('https://api.openalex.org/works/W2741809807', ignore_errors = true)
#   select id, unlist(json_extract_string(abstract_inverted_index, '$.*'))::integer[] as aii, json_keys(abstract_inverted_index) as keys) select unnest(aii) as i, array_extract(keys, i) as t order by i asc) select string_agg(t, ' ') as abs_aii;
# ```

# For this work id it gives this slightly "lossy" inverted inverted abstract:

# "Despite growing interest in Open Access (OA) to scholarly literature, there is an unmet need for large-scale, up-to-date, and reproducible studies assessing the prevalence characteristics of OA. We address this using oaDOI, online service determines OA status 67 million articles. use three samples, each 100,000 articles, investigate populations: (1) all journal articles assigned a Crossref DOI, (2) recent indexed Web Science, (3) viewed by users Unpaywall, open-source browser extension lets find oaDOI. estimate at least 28% literature (19M total) proportion growing, driven particularly growth Gold Hybrid. most year analyzed (2015) also has highest percentage (45%). Because growth, fact readers disproportionately newer Unpaywall encounter quite frequently: 47% they view are Notably, common mechanism not Gold, Green, or Hybrid OA, but rather under-discussed category dub Bronze: free-to-read on publisher website, without explicit license. examine citation impact corroborating so-called open-access advantage: accounting age discipline, receive 18% more citations than average, primarily Green further research free oaDOI service, as way inform policy practice."
