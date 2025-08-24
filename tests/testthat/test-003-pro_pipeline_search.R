library(testthat)
suppressPackageStartupMessages(library(openalexR))
# library(httptest)

# Normal Search `biodiversity AND finance`-------------------------------------

output_json <- file.path(tempdir(), "single_work")
output_jsonl <- file.path(tempdir(), "single_work_jsonl")
output_parquet <- file.path(tempdir(), "single_work_parquet")

unlink(output_json, recursive = TRUE, force = TRUE)
unlink(output_jsonl, recursive = TRUE, force = TRUE)
unlink(output_parquet, recursive = TRUE, force = TRUE)

test_that("pro_request search `biodiversity AND fiance`", {
  vcr::local_cassette("pro_request_search_biodiversity_AND_fiance")
  # Define the API request
  output_json <- pro_query(
    entity = "works",
    title_and_abstract.search = "biodiversity AND finance",
    to_publication_date = "2010-01-01"
  ) |>
    pro_request(
      pages = 1,
      output = output_json,
      mailto = "test@example.com",
      verbose = FALSE,
      progress = FALSE
    )

  # Check that the output file contains the expected data
  expect_snapshot_file(
    path = file.path(output_json, "results_page_1.json"),
    name = "json"
  )
})

test_that("pro_request_jsonl search `biodiversity AND finance`", {
  # Convert to parquet
  output_jsonl <- output_json |>
    pro_request_jsonl(
      output = output_jsonl,
      verbose = FALSE
    )

  # Check that the output file contains the expected data
  expect_snapshot_file(
    file.path(output_jsonl, "results_page_1.json"),
    ,
    name = "jsonl"
  )
})

test_that("pro_request_jsonl_parquet search `biodiversity AND finance`", {
  # Convert to parquet
  output_parquet <- output_jsonl |>
    pro_request_jsonl_parquet(
      output = output_parquet,
      verbose = FALSE
    )

  # Check that the output file exists
  expect_true(
    length(list.files(output_parquet, "*.parquet", recursive = TRUE)) >= 1
  )

  # Get search results from openalexR::oa_fetch(output = "tibble") for
  # comparison

  results_openalexR <- openalexR::oa_fetch(
    title_and_abstract.search = "biodiversity AND finance",
    to_publication_date = "2010-01-01",
    output = "tibble",
    verbose = FALSE
  )

  # Check that the output file contains the expected data structure
  expect_snapshot({
    results_openalexPro <- read_corpus(
      output_parquet,
      return_data = FALSE
    )
    nrow(results_openalexPro)
    names(results_openalexPro) |>
      sort()

    results_openalexPro <- results_openalexPro |>
      dplyr::select(id) |>
      dplyr::collect()

    setdiff(results_openalexR$id, results_openalexPro$id) |>
      sort() |>
      print()

    setdiff(results_openalexPro$id, results_openalexR$id) |>
      sort() |>
      print()

    intersect(results_openalexPro$id, results_openalexR$id) |>
      sort() |>
      print()
  })

  expect_true(
    setequal(results_openalexR$id, results_openalexPro$id)
  )

  #   # expect_snapshot_file(file.path(output_json, "results_page_1.json"))
})

unlink(output_json, recursive = TRUE, force = TRUE)
unlink(output_jsonl, recursive = TRUE, force = TRUE)
unlink(output_parquet, recursive = TRUE, force = TRUE)
