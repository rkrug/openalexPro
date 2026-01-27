library(testthat)

testthat::test_that("build_corpus_index creates correct Feather index", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_file <- file.path(tempdir(), "test_index.feather")

  # Create a small test parquet file with known data
  test_data <- data.frame(
    id = c(
      "https://openalex.org/W1000000001",
      "https://openalex.org/W1000000002",
      "https://openalex.org/W1000000003",
      "https://openalex.org/W2000000001",
      "https://openalex.org/W2000000002"
    ),
    doi = c(
      "https://doi.org/10.1000/test1",
      "https://doi.org/10.1000/test2",
      NA,
      "https://doi.org/10.1000/test4",
      NA
    ),
    title = c("Paper 1", "Paper 2", "Paper 3", "Paper 4", "Paper 5"),
    stringsAsFactors = FALSE
  )

  # Write test parquet file
  arrow::write_parquet(test_data, file.path(corpus_dir, "test.parquet"))

  # Build the index
  result <- build_corpus_index(
    corpus_dir = corpus_dir,
    index_file = index_file
  )

  # Check return value
  expect_equal(result, index_file)
  expect_true(file.exists(index_file))

  # Read and verify the index
 index <- arrow::read_feather(index_file)

  # Check columns exist
  expect_true("id" %in% names(index))
  expect_true("doi" %in% names(index))
  expect_true("id_block" %in% names(index))
  expect_true("parquet_file" %in% names(index))
  expect_true("file_row_number" %in% names(index))

  # Check row count matches
  expect_equal(nrow(index), nrow(test_data))

  # Check IDs are all present
  expect_setequal(index$id, test_data$id)

  # Check id_block calculation is correct
  # W1000000001 -> 1000000001 // 10000 = 100000
  # W2000000001 -> 2000000001 // 10000 = 200000
  expect_true(100000 %in% index$id_block)
  expect_true(200000 %in% index$id_block)

  # Check file_row_number is 0-indexed
  expect_true(all(index$file_row_number >= 0))

  # Check DOI values are preserved correctly
  # Sort both by id for comparison
  index_sorted <- index[order(index$id), ]
  test_sorted <- test_data[order(test_data$id), ]
  expect_equal(index_sorted$doi, test_sorted$doi)

  # Check that NA DOIs are preserved (2 NAs in test data)
  expect_equal(sum(is.na(index$doi)), 2)

  # Check DOI lookup works - find record by DOI
  doi_lookup <- index[index$doi == "https://doi.org/10.1000/test1" & !is.na(index$doi), ]
  expect_equal(nrow(doi_lookup), 1)
  expect_equal(doi_lookup$id, "https://openalex.org/W1000000001")

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_file)
})

testthat::test_that("build_corpus_index errors on non-existent directory", {
  expect_error(
    build_corpus_index(
      corpus_dir = "/non/existent/path",
      index_file = tempfile()
    ),
    "corpus_dir does not exist"
  )
})
