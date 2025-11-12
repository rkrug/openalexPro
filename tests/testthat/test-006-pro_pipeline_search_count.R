library(testthat)
suppressPackageStartupMessages(library(openalexR))
# library(httptest)

# Normal Search `biodiversity AND finance`-------------------------------------

output_json <- file.path(tempdir(), "search_work")
output_jsonl <- file.path(tempdir(), "search_work_jsonl")
output_parquet <- file.path(tempdir(), "search_work_parquet")

unlink(output_json, recursive = TRUE, force = TRUE)
unlink(output_jsonl, recursive = TRUE, force = TRUE)
unlink(output_parquet, recursive = TRUE, force = TRUE)

test_that("pro_request search count `biodiversity AND fiance`", {
  vcr::local_cassette("pro_request_search_biodiversity_AND_fiance_count")
  # Define the API request
  count <- pro_query(
    entity = "works",
    title_and_abstract.search = "biodiversity AND finance",
    to_publication_date = "2010-01-01"
  ) |>
    pro_request(
      output = output_json,
      mailto = "test@example.com",
      verbose = FALSE,
      progress = FALSE,
      count_only = TRUE
    )

  # Check that the output file contains the expected data
  expect_snapshot(
    count
  )
})


test_that("pro_request search count and openalexR::oa_fetch() return same results", {
  vcr::local_cassette("pro_request_search_biodiversity_AND_fiance_count")
  # Define the API request
  count <- pro_query(
    entity = "works",
    title_and_abstract.search = "biodiversity AND finance",
    to_publication_date = "2010-01-01"
  ) |>
    pro_request(
      output = output_json,
      mailto = "test@example.com",
      verbose = FALSE,
      progress = FALSE,
      count_only = TRUE
    )
  # Get search results from openalexR::oa_fetch(output = "tibble") for
  # comparison

  vcr::local_cassette("oa_fetch_biodiversity_AND_finance")
  count_oa <- openalexR::oa_fetch(
    title_and_abstract.search = "biodiversity AND finance",
    to_publication_date = "2010-01-01",
    output = "tibble",
    verbose = FALSE,
    count_only = TRUE
  )

  # Check that the output file contains the expected data structure
  expect_snapshot({
    count_oa
    count
    identical(count_oa$count, count[["count"]])
  })
})

unlink(output_json, recursive = TRUE, force = TRUE)
unlink(output_jsonl, recursive = TRUE, force = TRUE)
unlink(output_parquet, recursive = TRUE, force = TRUE)
