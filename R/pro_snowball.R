#' A function to perform a snowball search and convert the result to a
#' tibble/data frame.
#' @param identifier Character vector of openalex identifiers.
#' @param doi Character vector of dois.
#' @param output parquet dataset; default: temporary directory.
#' @param verbose Logical indicating whether to show a verbose information.
#'   Defaults to `FALSE`
#'
#' @return A list containing 2 elements:
#' - nodes: dataframe with publication records.
#' The last column `oa_input` indicates whether the work was one of the input
#'   `identifier`(s).
#' - edges: publication link dataframe of 2 columns `from, to`
#' such that a row `A, B` means A -> B means A cites B. In bibliometrics, the
#'   "citation action" comes from A to B.
#'
#' @export
#'
#' @importFrom duckdb duckdb duckdb_register_arrow
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#' @importFrom arrow write_parquet
#'
#' @md
#'
pro_snowball <- function(
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
    dir.create(output, recursive = TRUE)
  }

  pro_snowball_get_nodes(
    identifier = identifier,
    doi = doi,
    output = output,
    verbose = verbose
  ) |>
    pro_snowball_extract_edges(
      output = output,
      verbose = verbose
    ) |>
    invisible()

  # Return path to snowball ------------------------------------------------

  return(normalizePath(output))
}
