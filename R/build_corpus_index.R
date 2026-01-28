#' Build a Parquet index for fast ID lookups in a parquet corpus
#'
#' This function creates a Parquet index that maps a specified ID column
#' to its physical location in the parquet corpus. This enables fast random
#' access to specific records without scanning entire partitions.
#'
#' The function is memory-efficient and can handle 300M+ records by using
#' DuckDB's COPY TO command to write directly to the output without
#' loading data into R memory.
#'
#' @param corpus_dir Path to the parquet corpus directory.
#' @param index_dir Output path for the index. For OpenAlex ID indexes
#'   (`id_column = "id"`), this is a directory with hive-partitioned parquet
#'   files by `id_block`. For DOI indexes (`id_column = "doi"`), this is a
#'   single parquet file path.
#' @param id_column Name of the column to index. Default is `"id"` for OpenAlex
#'   IDs. Use `"doi"` to create a DOI index.
#' @param merge_partitions Logical. For partitioned indexes (`id_column = "id"`),
#'   whether to merge multiple files per partition into a single file. Default
#'   is `TRUE` for cleaner output. Set to `FALSE` for faster index building
#'   (lookup still works correctly with multiple files per partition).
#' @param memory_limit DuckDB memory limit (e.g., "20GB"). Default is `NULL`.
#' @param threads Number of DuckDB threads. Default is `NULL` (use all cores).
#'
#' @return Invisibly returns the path to the created index.
#'
#' @details
#' The index contains the following columns:
#' \describe{
#'   \item{id}{The indexed column (renamed to "id" regardless of source column)}
#'   \item{parquet_file}{Path to the parquet file in the corpus}
#'   \item{file_row_number}{Row number within the file (0-indexed)}
#' }
#'
#' For OpenAlex ID indexes (`id_column = "id"`), the index is partitioned by
#' `id_block` (computed as `floor(numeric_id / 10000)`). This enables O(1)
#' lookups by first computing the ID block, then reading only that partition.
#'
#' For DOI indexes (`id_column = "doi"`), the index is a single file since
#' DOIs have no predictable structure for partitioning.
#'
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery
#' @importFrom duckdb duckdb
#'
#' @examples
#' \dontrun{
#' # Build partitioned index for OpenAlex IDs (fast O(1) lookup)
#' build_corpus_index(
#'   corpus_dir = "/Volumes/openalex/arrow/works",
#'   index_dir = "/Volumes/openalex/arrow/works_id_index",
#'   id_column = "id",
#'   memory_limit = "20GB"
#' )
#'
#' # Build single-file index for DOIs
#' build_corpus_index(
#'   corpus_dir = "/Volumes/openalex/arrow/works",
#'   index_dir = "/Volumes/openalex/arrow/works_doi_index.parquet",
#'   id_column = "doi",
#'   memory_limit = "20GB"
#' )
#' }
#'
#' @export
#' @md
build_corpus_index <- function(
  corpus_dir,
  index_dir,
  id_column = "id",
  merge_partitions = TRUE,
  memory_limit = NULL,
  threads = NULL
) {
  if (!dir.exists(corpus_dir)) {
    stop("corpus_dir does not exist: ", corpus_dir)
  }

  if (dir.exists(index_dir)) {
    warning(
      "index_dir exists - creeation skipped - delete manually to re-create: ",
      corpus_dir
    )
    return(invisible(NULL))
  }

  ## For partitioned output (id), create parent directory
  ## For single file output (doi), create parent directory
  parent_dir <- if (id_column == "id") {
    index_dir
  } else {
    dirname(index_dir)
  }
  if (!dir.exists(parent_dir)) {
    dir.create(parent_dir, recursive = TRUE)
  }

  con <- DBI::dbConnect(duckdb::duckdb(), read_only = FALSE)

  on.exit(
    DBI::dbDisconnect(con, shutdown = TRUE)
  )

  ## Apply performance settings
  DBI::dbExecute(conn = con, "SET preserve_insertion_order = false")
  if (!is.null(memory_limit)) {
    DBI::dbExecute(
      conn = con,
      paste0("SET memory_limit = '", memory_limit, "'")
    )
  }
  if (!is.null(threads)) {
    DBI::dbExecute(
      conn = con,
      paste0("SET threads = ", threads)
    )
  }

  message("Building index from: ", corpus_dir)
  message("    Indexing column: ", id_column)
  message("    Writing to: ", index_dir)

  total_start <- Sys.time()

  ## Use COPY TO to write directly to parquet - avoids loading into R memory
  ## This is critical for 300M+ records which would require ~60GB RAM otherwise

  if (id_column == "id") {
    ## For OpenAlex IDs: partition by id_block for O(1) lookups
    ## id_block = floor(numeric_part / 10000)
    message("Creating partitioned index by id_block...")

    ## OpenAlex ID format: https://openalex.org/W1234567890
    ## - Prefix 'https://openalex.org/' is 21 chars
    ## - Position 22 is the entity type letter (W, A, I, etc.)
    ## - Position 23+ is the numeric ID
    ## id_block = floor(numeric_id / 10000)
    copy_query <- paste0(
      "COPY (",
      "SELECT ",
      "  id, ",
      "  CAST(FLOOR(CAST(SUBSTR(id, 23) AS BIGINT) / 10000) AS INTEGER) ",
      "    AS id_block, ",
      "  filename AS parquet_file, ",
      "  file_row_number ",
      "FROM read_parquet('",
      corpus_dir,
      "/**/*.parquet', filename = true, file_row_number = true)",
      ") TO '",
      index_dir,
      "' (FORMAT PARQUET, PARTITION_BY (id_block), COMPRESSION ZSTD, ",
      "OVERWRITE_OR_IGNORE)"
    )
  } else {
    ## For DOIs: single file (no predictable partitioning structure)
    message("    Creating single-file index...")

    copy_query <- paste0(
      "COPY (",
      "SELECT ",
      "  ",
      id_column,
      " AS id, ",
      "  filename AS parquet_file, ",
      "  file_row_number ",
      "FROM read_parquet('",
      corpus_dir,
      "/**/*.parquet', filename = true, file_row_number = true)",
      ") TO '",
      index_dir,
      "' (FORMAT PARQUET, COMPRESSION ZSTD)"
    )
  }

  message("    Executing index query (streaming to file)...")
  DBI::dbExecute(conn = con, copy_query)

  ## For partitioned output, optionally merge multiple files per partition
  if (id_column == "id" && merge_partitions) {
    message("Merging partition files...")

    ## Find all partition directories
    partition_dirs <- list.dirs(index_dir, recursive = FALSE, full.names = TRUE)

    for (part_dir in partition_dirs) {
      part_files <- list.files(
        part_dir,
        pattern = "\\.parquet$",
        full.names = TRUE
      )

      if (length(part_files) > 1) {
        ## Multiple files - merge them
        merged_file <- file.path(part_dir, "data.parquet")
        temp_file <- file.path(part_dir, "merged_temp.parquet")

        merge_query <- paste0(
          "COPY (SELECT * FROM read_parquet('",
          part_dir,
          "/*.parquet')) TO '",
          temp_file,
          "' (FORMAT PARQUET, COMPRESSION ZSTD)"
        )
        DBI::dbExecute(conn = con, merge_query)

        ## Remove original files and rename temp
        file.remove(part_files)
        file.rename(temp_file, merged_file)
      }
    }

    message("Partition merge complete")
  }

  ## Get row count for reporting
  count_query <- paste0(
    "SELECT COUNT(*) as n FROM read_parquet('",
    index_dir,
    if (id_column == "id") "/**/*.parquet')" else "')"
  )
  row_count <- DBI::dbGetQuery(conn = con, count_query)$n

  message(
    "Index built: ",
    format(row_count, big.mark = ","),
    " rows"
  )

  ## Report size
  if (id_column == "id") {
    ## Sum sizes of all partition files
    index_files <- list.files(
      index_dir,
      pattern = "\\.parquet$",
      recursive = TRUE,
      full.names = TRUE
    )
    total_size <- sum(file.info(index_files)$size)
    file_size_gb <- round(total_size / 1024^3, 2)
    message(
      "Done! Index size: ",
      file_size_gb,
      " GB across ",
      length(index_files),
      " partition files"
    )
  } else {
    file_size_gb <- round(file.info(index_dir)$size / 1024^3, 2)
    message(
      "Done! Index file size: ",
      file_size_gb,
      " GB"
    )
  }

  message(
    "Total time: ",
    round(difftime(Sys.time(), total_start, units = "mins"), 2),
    " minutes"
  )

  invisible(index_dir)
}
