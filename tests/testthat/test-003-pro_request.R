library(testthat)
# library(httptest)

# with_mock_dir("pro_request_biodiversity_AND_toast", {
test_that("pro_request searches for `biodiversity AND toast`", {
  # Define the API request
  output_dir <- oa_query(
    title_and_abstract.search = "biodiversity AND toast"
  ) |>
    pro_request(
      pages = 1,
      output_dir = file.path(tempdir(), "biodiversity_AND_toast"),
      mailto = "test@example.com"
    )

  # Check that the output directory exists
  expect_true(dir.exists(output_dir))

  # Check that the output file exists
  expect_true(file.exists(file.path(output_dir, "results_page_1.json")))

  expect_snapshot_file(file.path(output_dir, "results_page_1.json"))

  # Check that the output file contains the expected data

  # Clean up temporary files
  unlink(output_dir)
})
# })

test_that("pro_request searches for `biodiversity AND toast` and group by type", {
  # Define the API request
  output_dir <- oa_query(
    title_and_abstract.search = "biodiversity",
    group_b = "type"
  ) |>
    pro_request(
      pages = 1,
      output_dir = file.path(tempdir(), "biodiversity_AND_toast_group_by_type"),
      mailto = "test@example.com"
    )

  # Check that the output directory exists
  expect_true(dir.exists(output_dir))

  # Check that the output file exists
  expect_true(file.exists(file.path(output_dir, "group_by_page_1.json")))

  expect_snapshot_file(file.path(output_dir, "group_by_page_1.json"))

  # Check that the output file contains the expected data

  # Clean up temporary files
  unlink(output_dir)
})
