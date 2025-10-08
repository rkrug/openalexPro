library(testthat)
# library(httptest)

# single work ------------------------------------------------------------

output_json <- file.path(tempdir(), "single_work")
output_jsonl <- file.path(tempdir(), "single_work_jsonl")
output_parquet <- file.path(tempdir(), "single_work_parquet")

unlink(output_json, recursive = TRUE, force = TRUE)
unlink(output_jsonl, recursive = TRUE, force = TRUE)
unlink(output_parquet, recursive = TRUE, force = TRUE)

test_that("pro_request single identifier", {
  vcr::local_cassette("pro_request_single_identifier")
  # Define the API request
  output_json <- pro_query(
    entity = "works",
    id = "W2162348455"
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
    file.path(output_json, "single_1.json"),
    name = "json"
  )
})

test_that("pro_request_jsonl single identifier", {
  # Convert to parquet
  output_jsonl <- output_json |>
    pro_request_jsonl(
      output = output_jsonl,
      verbose = FALSE
    )

  # Check that the output file contains the expected data
  expect_snapshot_file(
    file.path(output_jsonl, "single_1.json"),
    name = "jsonl"
  )
})

test_that("pro_request_jsonl_parquet single identifier", {
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

  # Check that the output file contains the expected data structure
  expect_snapshot({
    x <- read_corpus(
      output_parquet,
      return_data = FALSE
    )
    nrow(x)
    names(x) |>
      sort()
  })

  # Check that the output file contains the expected data
  # expect_snapshot_file(file.path(output_json, "results_page_1.json"))
})

unlink(output_json, recursive = TRUE, force = TRUE)
unlink(output_jsonl, recursive = TRUE, force = TRUE)
unlink(output_parquet, recursive = TRUE, force = TRUE)
