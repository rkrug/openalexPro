#' Convert JSON files to Apache Parquet files
#'
#'
#' The function takes a directory of JSON files as written from a call to
#' `pro_request(..., output = "FOLDER")` and is preparing the json files to be
#' processed further using DuckDB. See
#' @details See \code{\link{jq_execute}} or the \code{\link{vignette}}("jq",
#'   package = "openalexPro2") for more information on the conversion of the
#'   JSON files.
#'
#' @param input_json The directory of JSON files returned from `pro_request(...,
#'   json_dir = "FOLDER")`.
#' @param output output directory for the jsonl files as created by calls to
#'   `jq_execute().
#' @param add_columns List of additional fields to be added to the output. They
#'   nave to be provided as a named list, e./g. `list(column_1 = "value_1",
#'   column_2 = 2)`. Only Scalar values are supported.
#' @param overwrite Logical indicating whether to overwrite `output`.
#' @param verbose Logical indicating whether to show a verbose information.
#'   Defaults to `TRUE`
#' @param delete_input Determines if the `input_json` should be deleted
#'   afterwards. Defaults to `FALSE`.
#'
#' @return The function does returns the output invisibly.
#'
#' @details The function uses DuckDB to read the JSON files and to create the
#'   Apache Parquet files. The function creates a DuckDB connection in memory
#'   and readsds the JSON files into DuckDB when needed. Then it creates a SQL
#'   query to convert the JSON files to Apache Parquet files and to copy the
#'   result to the specified directory.
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#'
#' @md
#'
#' @examples
#' \dontrun{
#'   source_to_parquet(
#'   input_json = "json",
#'   source_type = "snapshot",
#'   output = "parquet"
#' ) }
#'
#' @export

pro_request_jsonl <- function(
  input_json = NULL,
  output = NULL,
  add_columns = list(),
  overwrite = FALSE,
  verbose = TRUE,
  delete_input = FALSE
) {
  # Argument checks --------------------------------------------------------

  if (is.null(output)) {
    stop("No `output` output folder specified!")
  }

  ## Check if input_json is specified
  if (is.null(input_json)) {
    stop("No `input_json`_dir to convert specified!")
  }

  ## Check if output is specified
  if (is.null(output)) {
    stop("No output to convert to specified!")
  }

  if (file.exists(output)) {
    if (!(overwrite)) {
      stop(
        "output ",
        output,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    } else {
      unlink(
        output,
        recursive = TRUE,
        force = TRUE
      )
    }
  }
  dir.create(output, recursive = TRUE)

  ## Read names of json files
  jsons <- list.files(
    input_json,
    pattern = "*.json$",
    full.names = TRUE,
    recursive = TRUE
  )

  has_subdirs <- length(list.dirs(input_json)) > 1

  jsons <- jsons[
    order(
      as.numeric(
        sub(
          ".*_([0-9]+)\\.json$",
          "\\1",
          jsons
        )
      )
    )
  ]

  types <- jsons |>
    basename() |>
    strsplit(split = "_") |>
    vapply(
      FUN = '[[',
      1,
      FUN.VALUE = character(1)
    ) |>
    unique()

  if (length(types) > 1) {
    stop("All JSON files must be of the same type!")
  }

  if (types == "group") {
    types <- "group_by"
  }

  # Go through all jsons, i.e. one per page --------------------------------
  ### Names: results_page_x.json

  for (i in seq_along(jsons)) {
    fn <- jsons[i]
    if (verbose) {
      message("Preparing ", i, " of ", length(jsons), " : ", fn)
    }

    ## Extract page number into pn
    pn <- basename(fn) |>
      strsplit(split = "_")
    pn <- pn[[1]]

    # pn <- pn[[1]][length(pn[[1]])] |>
    pn <- pn[length(pn)] |>
      gsub(pattern = ".json", replacement = "")

    if (has_subdirs) {
      jsonl <- file.path(output, basename(dirname(fn)), basename(fn))
      pn <- paste0(basename(dirname(fn)), "_", pn)
    } else {
      jsonl <- file.path(output, basename(fn))
      pn = pn
    }
    dir.create(dirname(jsonl), recursive = TRUE, showWarnings = FALSE)

    try(
      {
        ## do the following in the json:"
        ## - Convert `inverted_abstract_index` to `abstract`
        ## - remove `inverted_abstract_index`
        ## - add `page` = pn
        jq_execute(
          input_json = fn,
          output_jsonl = jsonl,
          add_columns = add_columns,
          jq_filter = NULL,
          page = pn,
          type = types
        )
        if (file.size(jsonl) < 5) {
          unlink(jsonl)
        }
      },
      silent = !verbose
    )
  }

  if (verbose) {
    message("Done")
  }

  if (delete_input) {
    unlink(input_json, recursive = TRUE, force = TRUE)
  }

  return(invisible(normalizePath(output)))
}
