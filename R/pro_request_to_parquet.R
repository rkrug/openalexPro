#' Convert JSON files to Apache Parquet files

#'
#' The function takes a directory of JSON files as written from a call to `pro_request(..., json_dir = "FOLDER")`
#' and converts it to a Apache Parquet dataset partitiond by the page.
#'
#' @param json_dir The directory of JSON files returned from `pro_request(..., json_dir = "FOLDER")`.
#' @param output_dir output  directory for the parquet dataset; default: temporary directory.
#' @param overwrite Logical indicating whether to overwrite `output_dir` and `output_nn`.
#' @param verbose Logical indicating whether to show a verbose information. Defaults to `TRUE`
#' @param delete_input Determines if the `json_dir` should be deleted afterwards. Defaults to `FALSE`.
#' @param jq_path Path to the jq executable (default: "jq")
#' @param ROW_GROUP_SIZE Only used when `normalize_schemata = TRUE`. Maximum number of rows per row group. Smaller sizes reduce memory
#'   usage, larger sizes improve compression. Defaults to `10000`.
#'   See: \url{https://duckdb.org/docs/sql/statements/copy#row_group_size}
#' @param ROW_GROUPS_PER_FILE Only used when `normalize_schemata = TRUE`. Number of row groups to include in each output Parquet file.
#'   Controls file size and write frequency. Defaults to `1`
#'   See: \url{https://duckdb.org/docs/sql/statements/copy#row_groups_per_file}
#' @param output_nn output  directory for the non-normalized parquet dataset; default: temporary directory.
#'   Mainly for debugging purposes needed.
#' @return The function does returns the output_directory invisibly.
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
#' source_to_parquet(json_dir = "json", source_type = "snapshot", output_dir = "arrow")
#' }
#' @export

pro_request_to_parquet <- function(
  json_dir = NULL,
  output_dir = tempfile(fileext = "_parquet"),
  overwrite = FALSE,
  verbose = TRUE,
  delete_input = FALSE,
  jq_path = "jq",
  ROW_GROUP_SIZE = 10000,
  ROW_GROUPS_PER_FILE = 1,
  output_nn = tempfile(fileext = "_parquet_raw")
) {
  ## Check if json_dir is specified
  if (is.null(json_dir)) {
    stop("No json_dir to convert from specified!")
  }

  ## Check if output_dir is specified
  if (is.null(output_dir)) {
    stop("No output_dir to convert to specified!")
  }

  if (file.exists(output_dir)) {
    if (!(overwrite)) {
      stop(
        "output_dir ",
        output_dir,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    } else {
      unlink(
        output_dir,
        recursive = TRUE,
        force = TRUE
      )
    }
  }

  if (file.exists(output_nn)) {
    if (!(overwrite)) {
      stop(
        "output_nn ",
        output_nn,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    } else {
      unlink(
        output_nn,
        recursive = TRUE,
        force = TRUE
      )
    }
  }
  ## Read names of json files
  jsons <- list.files(
    json_dir,
    pattern = "*.json$",
    full.names = TRUE
  )

  jsons <- jsons[
    order(
      as.numeric(
        sub(
          ".*results_page_(\\d+)\\.json",
          "\\1",
          jsons
        )
      )
    )
  ]

  types <- jsons |>
    basename() |>
    strsplit(split = "_") |>
    sapply(FUN = '[[', 1) |>
    unique()

  if (length(types) > 1) {
    stop("All JSON files must be of the same type!")
  }

  if (types == "group") {
    types <- "group_by"
  }

  # pb <- txtProgressBar(min = 0, max = length(jsons), style = 3) # style 3 = nice bar

  ## Create and setup in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    }
  )
  paste0(
    "INSTALL json; LOAD json; "
  ) |>
    DBI::dbExecute(conn = con)

  dir.create(
    output_nn,
    recursive = TRUE,
    showWarnings = FALSE
  )

  ### Go through all jsons, i.e. one per page.
  ### Names: results_page_x.json
  #
  for (i in seq_along(jsons)) {
    fn <- jsons[i]
    if (verbose) {
      message("Converting ", i, " of ", length(jsons), " : ", fn)
    }

    ## Extract page number into pn
    pn <- basename(fn) |>
      strsplit(split = "_")

    pn <- pn[[1]][length(pn[[1]])] |>
      gsub(pattern = ".json", replacement = "")

    try(
      {
        ## do the following int the json:"
        ## - Convert `inverted_abstract_index` to `abstract`
        ## remove `inverted_abstract_index`
        ## add `page` = pn
        jsonl <- tempfile(fileext = ".jsonl")
        jq_execute(
          input_json = fn,
          output_json = jsonl,
          jq_path = jq_path,
          jq_filter = NULL,
          page = pn,
          type = types
        )
        ## save as page partitioned parquet
        if (file.size(jsonl) > 1) {
          query <- sprintf(
            "
          COPY (
            SELECT
              *
            FROM 
              read_json_auto( '%s' )
          ) TO
            '%s'
          (FORMAT PARQUET, COMPRESSION SNAPPY, APPEND, PARTITION_BY 'page')
          ",
            jsonl,
            output_nn
          )
          DBI::dbExecute(conn = con, query)

          unlink(jsonl)
          if (verbose) {
            message("   Done")
          }
        } else {
          message("   Nothing to import")
        }
      },
      silent = !verbose
    )
    # setTxtProgressBar(pb, i)
  }

  ## normalize parquet dataset schemata into non-partitioned dataset
  #
  if (verbose) {
    message("Normalizing Schemata")
  }
  normalize_parquet(
    input_dir = output_nn,
    output_dir = output_dir,
    overwrite = FALSE,
    delete_input = FALSE,
    ROW_GROUP_SIZE = ROW_GROUP_SIZE,
    ROW_GROUPS_PER_FILE = ROW_GROUPS_PER_FILE
  )
  if (verbose) {
    message("   Done")
  }

  if (delete_input) {
    unlink(json_dir, recursive = TRUE, force = TRUE)
  }

  return(invisible(normalizePath(output_dir)))
}
