library(testthat)

testthat::test_that("jq_execute correctly applies jq filter and writes output to JSONL file", {
  # Create temporary output JSONL files
  output_jsonl_default <- file.path(tempdir(), "default.jsonl")
  output_jsonl_page <- file.path(tempdir(), "page.jsonl")
  output_jsonl_filter <- file.path(tempdir(), "jq_filter.jsonl")

  input_json <- testthat::test_path(
    "..",
    "fixtures",
    "keypaper_json",
    "results_page_1.json"
  )

  # Execute jq_execute
  jq_execute(
    input_json = input_json,
    output_jsonl = output_jsonl_default
  )

  # Check if the output JSONL file matches the snapshot
  expect_snapshot_file(output_jsonl_default)

  # Execute jq_execute
  jq_execute(
    input_json = input_json,
    output_jsonl = output_jsonl_page,
    page = 2
  )

  # Check if the output JSONL file matches the snapshot
  expect_snapshot_file(output_jsonl_page)

  # Execute jq_execute
  jq_execute(
    input_json = input_json,
    output_jsonl = output_jsonl_filter,
    jq_filter = ".results[] | select(.id == 1)"
  )

  # Check if the output JSONL file matches the snapshot
  expect_snapshot_file(output_jsonl_filter)

  # Clean up temporary files
  unlink(output_jsonl_default)
  unlink(output_jsonl_page)
  unlink(output_jsonl_page)
})
