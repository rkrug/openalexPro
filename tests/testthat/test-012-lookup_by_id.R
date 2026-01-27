library(testthat)

testthat::test_that("lookup_by_id retrieves correct records by ID", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus_lookup")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_file <- file.path(tempdir(), "test_index_lookup.feather")

  # Create test data
  test_data <- data.frame(
    id = c(
      "https://openalex.org/W1000000001",
      "https://openalex.org/W1000000002",
      "https://openalex.org/W1000000003"
    ),
    doi = c(
      "https://doi.org/10.1000/test1",
      "https://doi.org/10.1000/test2",
      NA
    ),
    title = c("Paper 1", "Paper 2", "Paper 3"),
    year = c(2020, 2021, 2022),
    stringsAsFactors = FALSE
  )

  # Write test parquet
  arrow::write_parquet(test_data, file.path(corpus_dir, "test.parquet"))

  # Build index
  build_corpus_index(
    corpus_dir = corpus_dir,
    index_file = index_file
  )

  # Test lookup by ID (long form)
  result <- lookup_by_id(
    index_file = index_file,
    ids = "https://openalex.org/W1000000001"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 1")

  # Test lookup by ID (short form)
  result <- lookup_by_id(
    index_file = index_file,
    ids = "W1000000002"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 2")

  # Test lookup multiple IDs
  result <- lookup_by_id(
    index_file = index_file,
    ids = c("W1000000001", "W1000000003")
  )
  expect_equal(nrow(result), 2)
  expect_setequal(result$title, c("Paper 1", "Paper 3"))

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_file)
})

testthat::test_that("lookup_by_id retrieves correct records by DOI", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus_doi")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_file <- file.path(tempdir(), "test_index_doi.feather")

  # Create test data
  test_data <- data.frame(
    id = c(
      "https://openalex.org/W1000000001",
      "https://openalex.org/W1000000002"
    ),
    doi = c(
      "https://doi.org/10.1000/test1",
      "https://doi.org/10.1000/test2"
    ),
    title = c("Paper 1", "Paper 2"),
    stringsAsFactors = FALSE
  )

  # Write test parquet
  arrow::write_parquet(test_data, file.path(corpus_dir, "test.parquet"))

  # Build index
  build_corpus_index(
    corpus_dir = corpus_dir,
    index_file = index_file
  )

  # Test lookup by DOI (with prefix)
  result <- lookup_by_id(
    index_file = index_file,
    dois = "https://doi.org/10.1000/test1"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 1")

  # Test lookup by DOI (without prefix)
  result <- lookup_by_id(
    index_file = index_file,
    dois = "10.1000/test2"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 2")

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_file)
})

testthat::test_that("lookup_by_id handles errors correctly", {
  skip_if_not_installed("arrow")

  # Test missing both ids and dois
  expect_error(
    lookup_by_id(index_file = tempfile()),
    "Either 'ids' or 'dois' must be provided"
  )

  # Test providing both ids and dois
  expect_error(
    lookup_by_id(index_file = tempfile(), ids = "W1", dois = "10.1/x"),
    "Provide either 'ids' or 'dois', not both"
  )

  # Test non-existent index file
  expect_error(
    lookup_by_id(index_file = "/nonexistent/path.feather", ids = "W1"),
    "Index file not found"
  )
})
