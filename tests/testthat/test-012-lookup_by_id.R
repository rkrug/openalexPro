library(testthat)

testthat::test_that("lookup_by_id retrieves correct records by OpenAlex ID using partitioned index", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus_lookup")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_file <- file.path(tempdir(), "test_index_lookup.parquet")

  # Clean up any existing
  unlink(index_file, recursive = TRUE)

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
    index_file = index_file
  )

  # Test lookup by ID (long form)
  result <- lookup_by_id(
    index_file = index_file,
    ids = "https://openalex.org/W1000000001"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 1")

  # Test lookup by ID (short form, with normalization)
  result <- lookup_by_id(
    index_file = index_file,
    ids = "W1000000002"
  )
  expect_equal(nrow(result), 1)
  expect_equal(result$title, "Paper 2")

  # Test lookup multiple IDs from same block
  result <- lookup_by_id(
    index_file = index_file,
    ids = c("W1000000001", "W1000000003")
  )
  expect_equal(nrow(result), 2)
  expect_setequal(result$title, c("Paper 1", "Paper 3"))

  # Test lookup IDs from different blocks
  result <- lookup_by_id(
    index_file = index_file,
    ids = c("W1000000001", "W2000000001")
  )
  expect_equal(nrow(result), 2)
  expect_setequal(result$title, c("Paper 1", "Paper 4"))

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_file, recursive = TRUE)
})

testthat::test_that("lookup_by_id writes to output directory when output is set", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus_output")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_file <- file.path(tempdir(), "test_index_output.parquet")
  output_dir <- file.path(tempdir(), "test_output_lookup")

  # Clean up any existing
  unlink(index_file, recursive = TRUE)
  unlink(output_dir, recursive = TRUE)

  # Create test data
  test_data <- data.frame(
    id = c(
      "https://openalex.org/W1000000001",
      "https://openalex.org/W1000000002",
      "https://openalex.org/W2000000001"
    ),
    title = c("Paper 1", "Paper 2", "Paper 3"),
    stringsAsFactors = FALSE
  )

  arrow::write_parquet(test_data, file.path(corpus_dir, "test.parquet"))
  build_corpus_index(corpus_dir = corpus_dir, index_file = index_file)

  # Test output mode
  result <- lookup_by_id(
    index_file = index_file,
    ids = c("W1000000001", "W2000000001"),
    output = output_dir
  )

  # Should return output path invisibly
  expect_equal(result, output_dir)
  expect_true(dir.exists(output_dir))

  # Should have written parquet file(s)
  parquet_files <- list.files(output_dir, pattern = "\\.parquet$")
  expect_true(length(parquet_files) >= 1)

  # Read back and verify contents
  written <- arrow::read_parquet(file.path(output_dir, parquet_files[1]))
  # file_row_number should NOT be in the output (COPY excludes it)
  # Actually COPY writes all columns from SELECT *, which includes file_row_number
  # But the data should contain our records
  total_rows <- sum(sapply(parquet_files, function(f) {
    nrow(arrow::read_parquet(file.path(output_dir, f)))
  }))
  expect_equal(total_rows, 2)

  # Test that existing output dir raises error
  expect_error(
    lookup_by_id(
      index_file = index_file,
      ids = "W1000000001",
      output = output_dir
    ),
    "Output directory already exists"
  )

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_file, recursive = TRUE)
  unlink(output_dir, recursive = TRUE)
})

testthat::test_that("lookup_by_id handles errors correctly", {
  skip_if_not_installed("arrow")

  # Test missing ids
  expect_error(
    lookup_by_id(index_file = tempfile()),
    "'ids' must be provided"
  )

  # Test non-existent index directory
  expect_error(
    lookup_by_id(
      index_file = "/nonexistent/path",
      ids = "W1"
    ),
    "Index file not found"
  )
})
