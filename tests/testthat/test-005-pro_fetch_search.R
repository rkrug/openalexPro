library(testthat)
suppressPackageStartupMessages(library(openalexR))
# library(httptest)

# Normal Search `biodiversity AND finance`-------------------------------------

output_dir <- file.path(tempdir(), "output")
# output_dir = "~/Documents/GitHub/openalexPro/search"

unlink(output_dir, recursive = TRUE, force = TRUE)

test_that("pro_fetch search `biodiversity AND fiance`", {
  vcr::local_cassette("pro_fetch_search_biodiversity_AND_finance")
  # Define the API request
  output_json <- pro_query(
    entity = "works",
    title_and_abstract.search = "biodiversity AND finance",
    to_publication_date = "2010-01-01"
  ) |>
    pro_fetch(
      pages = 1,
      output = output_dir,
      mailto = "test@example.com",
      verbose = FALSE,
      progress = FALSE
    )

  # Check that the output file contains the expected data
  expect_snapshot_file(
    path = file.path(output_dir, "json", "results_page_1.json"),
    name = "json"
  )

  # Check that the output file contains the expected data
  expect_snapshot_file(
    file.path(output_dir, "jsonl", "results_page_1.json"),
    name = "jsonl"
  )

  # Check that the output file exists
  expect_true(
    length(
      list.files(
        file.path(output_dir, "parquet"),
        "*.parquet",
        recursive = TRUE
      )
    ) >=
      1
  )
})

# unlink(output_dir, recursive = TRUE, force = TRUE)
