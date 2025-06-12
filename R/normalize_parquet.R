#' Normalize parquet files
#'
#' The function takes a directory of parquet files and normalizes the schemata.
#' **NB: All partitioning in the input parquet dataset will be lost!**
#'
#' @param input_dir The directory with the parquet files or a parquet dataset.
#' @param output_dir parquet dataset with the normalized schemata. Non
#'   partitioned, but split into several files.
#' @param overwrite Determines if the uputput parquet database shlud be
#'   overwritten if it exists. Defauls to `FALSE`.
#' @param ROW_GROUP_SIZE Maximum number of rows per row group. Smaller sizes
#'   reduce memory usage, larger sizes improve compression. Defaults to `10000`.
#'   See: \url{https://duckdb.org/docs/sql/statements/copy#row_group_size} for
#'   details.
#' @param ROW_GROUPS_PER_FILE Number of row groups to include in each output
#'   Parquet file. Controls file size and write frequency. Defaults to `1` See:
#'   \url{https://duckdb.org/docs/sql/statements/copy#row_groups_per_file} for
#'   details.
#' @param delete_input Determines if the `inputdir` should be deleted
#'   afterwards. Defaults to `FALSE`.
#'
#' @return The function does return the `output_dir`.
#'
#' @details The function uses DuckDB to normalize the schemata. The function
#'   creates a DuckDB connection in memory and reads the parquet files into
#'   DuckDB when needed and re-writes it in a non-partitioned parquet database
#'   with a normalized schemata.
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#'
#' @md
#'
#' @export

normalize_parquet <- function(
  input_dir = NULL,
  output_dir = NULL,
  overwrite = FALSE,
  ROW_GROUP_SIZE = 10000,
  ROW_GROUPS_PER_FILE = 1,
  delete_input = FALSE
) {
  # Argument Checks --------------------------------------------------------

  ## Check if input_dir is specified
  if (is.null(input_dir)) {
    stop("No `input_dir` specified!")
  }

  ## Check if output_dir is specified
  if (is.null(output_dir)) {
    stop("No `output_dir` specified!")
  }

  ## Check if input_dir is different from output_dir
  if (input_dir == output_dir) {
    stop("input_dir and output_dir cannot be the same!")
  }

  # Preparations -----------------------------------------------------------

  ## Prepare output dir
  if (file.exists(output_dir)) {
    if (!(overwrite)) {
      stop(
        "output_dir ",
        output_dir,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    } else {
      unlink(output_dir, recursive = TRUE, force = TRUE)
    }
  }

  ## Create in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(
    try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE),
    add = TRUE
  )

  # Normalizing Schemata ---------------------------------------------------

  sprintf(
    "
    COPY (
      SELECT 
        * 
      FROM 
        read_parquet('%s/**/*.parquet', union_by_name=true)
    )
    TO '%s' (
      FORMAT PARQUET,
      COMPRESSION SNAPPY,
      APPEND,
      ROW_GROUP_SIZE 10000,
      ROW_GROUPS_PER_FILE 1
    );
    ",
    input_dir,
    output_dir
  ) |>
    DBI::dbExecute(conn = con)

  if (delete_input) {
    unlink(input_dir, recursive = TRUE, force = TRUE)
  }

  return(normalizePath(output_dir))
}
