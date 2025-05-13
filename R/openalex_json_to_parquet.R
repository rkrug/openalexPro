#' Convert a folder of OpenAlex JSON files to partitioned Parquet
#'
#' This function converts all `results_page_*.json` files in a folder to a single
#' partitioned Parquet dataset, with one partition per `page`.
#'
#' @param input_dir Folder containing JSON files (e.g., results_page_1.json)
#' @param output_dir Output directory for partitioned Parquet dataset
#' @param jq_path Path to jq binary (default: \"jq\")
#' @return Invisibly returns the output directory path
#' @export
openalex_json_to_parquet <- function(
  input_dir,
  output_dir,
  jq_path = "jq"
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  files <- list.files(
    input_dir,
    pattern = "^results_page_[0-9]+\\.json$",
    full.names = TRUE
  )
  if (length(files) == 0) stop("No matching JSON files found in: ", input_dir)

  for (f in files) {
    page_match <- regexpr("[0-9]+", basename(f))
    page <- as.integer(regmatches(basename(f), page_match))
    if (is.na(page)) next

    message("Processing page ", page, " (", basename(f), ")")

    jsonl <- tempfile(fileext = ".jsonl")
    jq_execute(f, jsonl, jq_path = jq_path, page = page)

    tab <- arrow::read_json_arrow(jsonl, as_data_frame = FALSE)
    arrow::write_dataset(
      tab,
      path = output_dir,
      format = "parquet",
      partitioning = "page"
    )
  }

  invisible(output_dir)
}
