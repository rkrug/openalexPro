library(testthat)

testthat::test_that("lookup_by_id retrieves correct records by OpenAlex ID using partitioned index", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus_lookup")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_dir <- file.path(tempdir(), "test_index_lookup")

  # Clean up any existing
  unlink(index_dir, recursive = TRUE)

  # Create test data with IDs in different blocks
  test_data <- data.frame(
    id = c(
      "https://openalex.org/W1000000001",
      "https://openalex.org/W1000000002",
      "https://openalex.org/W1000000003",
      "https://openalex.org/W2000000001"
    ),
    doi = c(
      "https://doi.org/10.1000/test1",
      "https://doi.org/10.1000/test2",
      NA,
      "https://doi.org/10.1000/test4"
    ),
    title = c("Paper 1", "Paper 2", "Paper 3", "Paper 4"),
    year = c(2020, 2021, 2022, 2023),
    stringsAsFactors = FALSE
  )

  # Write test parquet
  arrow::write_parquet(test_data, file.path(corpus_dir, "test.parquet"))

  # Build partitioned index for OpenAlex IDs
  build_corpus_index(
    corpus_dir = corpus_dir,
    index_dir = index_dir,
    id_column = "id"
  )

  # Test lookup by ID (long form)
  result <- lookup_by_id(
    index_dir = index_dir,
    ids = "https://openalex.org/W1000000001",
    id_column = "id"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 1")

  # Test lookup by ID (short form, with normalization)
  result <- lookup_by_id(
    index_dir = index_dir,
    ids = "W1000000002",
    id_column = "id"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 2")

  # Test lookup multiple IDs from same block
  result <- lookup_by_id(
    index_dir = index_dir,
    ids = c("W1000000001", "W1000000003"),
    id_column = "id"
  )
  expect_equal(nrow(result), 2)
  expect_setequal(result$title, c("Paper 1", "Paper 3"))

  # Test lookup IDs from different blocks
  result <- lookup_by_id(
    index_dir = index_dir,
    ids = c("W1000000001", "W2000000001"),
    id_column = "id"
  )
  expect_equal(nrow(result), 2)
  expect_setequal(result$title, c("Paper 1", "Paper 4"))

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_dir, recursive = TRUE)
})

testthat::test_that("lookup_by_id retrieves correct records by DOI", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus_doi_lookup")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_file <- file.path(tempdir(), "test_doi_index_lookup.parquet")

  # Clean up any existing
  unlink(index_file)

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

  # Build single-file index for DOIs
  build_corpus_index(
    corpus_dir = corpus_dir,
    index_dir = index_file,
    id_column = "doi"
  )

  # Test lookup by DOI (with prefix)
  result <- lookup_by_id(
    index_dir = index_file,
    ids = "https://doi.org/10.1000/test1",
    id_column = "doi"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 1")

  # Test lookup by DOI (without prefix, with normalization)
  result <- lookup_by_id(
    index_dir = index_file,
    ids = "10.1000/test2",
    id_column = "doi"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 2")

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_file)
})

testthat::test_that("lookup_by_id handles errors correctly", {
  skip_if_not_installed("arrow")

  # Test missing ids
  expect_error(
    lookup_by_id(index_dir = tempfile()),
    "'ids' must be provided"
  )

  # Test non-existent index directory (for id column)
  expect_error(
    lookup_by_id(
      index_dir = "/nonexistent/path",
      ids = "W1",
      id_column = "id"
    ),
    "Index directory not found"
  )

  # Test non-existent index file (for doi column)
  expect_error(
    lookup_by_id(
      index_dir = "/nonexistent/path.parquet",
      ids = "10.1000/test",
      id_column = "doi"
    ),
    "Index file not found"
  )
})

testthat::test_that("lookup_by_id validates id_column parameter", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create a minimal index for testing
  corpus_dir <- file.path(tempdir(), "test_corpus_validate")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_dir <- file.path(tempdir(), "test_validate_index")

  # Clean up any existing
  unlink(index_dir, recursive = TRUE)

  test_data <- data.frame(
    id = "https://openalex.org/W1000000001",
    title = "Test",
    stringsAsFactors = FALSE
  )
  arrow::write_parquet(test_data, file.path(corpus_dir, "test.parquet"))
  build_corpus_index(corpus_dir = corpus_dir, index_dir = index_dir)

  # Test invalid id_column value
  expect_error(
    lookup_by_id(
      index_dir = index_dir,
      ids = "W1000000001",
      id_column = "invalid"
    ),
    "id_column must be"
  )

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_dir, recursive = TRUE)
})
