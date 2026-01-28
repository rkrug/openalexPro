library(testthat)

testthat::test_that("id_block computes correct ID blocks", {
  # Short form IDs
  expect_equal(id_block("W1000000001"), 100000L)
  expect_equal(id_block("W2741809807"), 274180L)

  # Long form IDs
  expect_equal(id_block("https://openalex.org/W1000000001"), 100000L)

  # Multiple IDs
  blocks <- id_block(c("W1000000001", "W1000000002", "W2000000001"))
  expect_equal(blocks, c(100000L, 100000L, 200000L))

  # Different entity types
  expect_equal(id_block("A123456789"), 12345L)
  expect_equal(id_block("I987654321"), 98765L)
})

testthat::test_that("build_corpus_index creates partitioned index for id column", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus_partitioned")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_dir <- file.path(tempdir(), "test_index_partitioned")

  # Clean up any existing index

  unlink(index_dir, recursive = TRUE)

  # Create test data with IDs in different blocks
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

  # Build the partitioned index (default id_column = "id")
  result <- build_corpus_index(
    corpus_dir = corpus_dir,
    index_dir = index_dir
  )

  # Check return value
  expect_equal(result, index_dir)
  expect_true(dir.exists(index_dir))

  # Check partition directories exist
  partitions <- list.dirs(index_dir, recursive = FALSE)
  expect_true(length(partitions) >= 1)

  # Read the partitioned index using DuckDB
  con <- DBI::dbConnect(duckdb::duckdb(), read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  index <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT * FROM read_parquet('", index_dir,
      "/**/*.parquet', hive_partitioning = true)"
    )
  )

  # Check columns exist (id, id_block, parquet_file, file_row_number)
  expect_true("id" %in% names(index))
  expect_true("id_block" %in% names(index))
  expect_true("parquet_file" %in% names(index))
  expect_true("file_row_number" %in% names(index))
  expect_false("doi" %in% names(index))

  # Check row count matches
  expect_equal(nrow(index), nrow(test_data))

  # Check IDs are all present
  expect_setequal(index$id, test_data$id)

  # Check id_block values are correct
  expected_blocks <- id_block(test_data$id)
  expect_setequal(index$id_block, expected_blocks)

  # Check file_row_number is 0-indexed
  expect_true(all(index$file_row_number >= 0))

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_dir, recursive = TRUE)
})

testthat::test_that("build_corpus_index creates single-file index for doi column", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  corpus_dir <- file.path(tempdir(), "test_corpus_doi")
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)
  index_file <- file.path(tempdir(), "test_doi_index.parquet")

  # Clean up any existing index
  unlink(index_file)

  # Create a small test parquet file with known data
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

  # Write test parquet file
  arrow::write_parquet(test_data, file.path(corpus_dir, "test.parquet"))

  # Build the DOI index (single file, not partitioned)
  result <- build_corpus_index(
    corpus_dir = corpus_dir,
    index_dir = index_file,
    id_column = "doi"
  )

  # Check return value
  expect_equal(result, index_file)
  expect_true(file.exists(index_file))

  # Read and verify the index
  index <- arrow::read_parquet(index_file)

  # Check columns exist (id column contains DOIs, no id_block)
  expect_true("id" %in% names(index))
  expect_true("parquet_file" %in% names(index))
  expect_true("file_row_number" %in% names(index))
  expect_false("id_block" %in% names(index))

  # Check row count matches
  expect_equal(nrow(index), nrow(test_data))

  # Check DOIs are all present (stored in "id" column)
  expect_setequal(index$id, test_data$doi)

  # Clean up
  unlink(corpus_dir, recursive = TRUE)
  unlink(index_file)
})

testthat::test_that("build_corpus_index errors on non-existent directory", {
  expect_error(
    build_corpus_index(
      corpus_dir = "/non/existent/path",
      index_dir = tempfile()
    ),
    "corpus_dir does not exist"
  )
})
