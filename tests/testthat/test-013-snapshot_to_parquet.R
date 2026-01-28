library(testthat)

testthat::test_that("snapshot_to_parquet converts JSON to Parquet", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary snapshot directory structure
  snapshot_dir <- file.path(tempdir(), "test_snapshot")
  arrow_dir <- file.path(tempdir(), "test_arrow")

  # Create expected directory structure: data/<dataset>/part_000/*.gz
  authors_dir <- file.path(snapshot_dir, "data", "authors", "part_000")
  dir.create(authors_dir, recursive = TRUE, showWarnings = FALSE)

  # Create test NDJSON data (one JSON object per line)
  test_authors <- c(
    '{"id":"https://openalex.org/A1","display_name":"Alice Smith","works_count":10}',
    '{"id":"https://openalex.org/A2","display_name":"Bob Jones","works_count":20}'
  )

  # Write gzipped NDJSON file
  gz_file <- file.path(authors_dir, "test.gz")
  gz_con <- gzfile(gz_file, "w")
  writeLines(test_authors, gz_con)
  close(gz_con)

  # Ensure clean output directory
  unlink(arrow_dir, recursive = TRUE)

  # Run conversion
  snapshot_to_parquet(
    snapshot_dir = snapshot_dir,
    arrow_dir = arrow_dir,
    data_sets = "authors"
  )

  # Verify output exists
  output_dir <- file.path(arrow_dir, "authors")
  expect_true(dir.exists(output_dir))

  # Read and verify the parquet data
  parquet_files <- list.files(output_dir, pattern = "\\.parquet$", full.names = TRUE)
  expect_true(length(parquet_files) > 0)

  result <- arrow::read_parquet(parquet_files[1])
  expect_equal(nrow(result), 2)
  expect_true("id" %in% names(result))
  expect_true("display_name" %in% names(result))
  expect_setequal(
    result$id,
    c("https://openalex.org/A1", "https://openalex.org/A2")
  )

  # Clean up

  unlink(snapshot_dir, recursive = TRUE)
  unlink(arrow_dir, recursive = TRUE)
})

testthat::test_that("snapshot_to_parquet skips existing data sets", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  snapshot_dir <- file.path(tempdir(), "test_snapshot_skip")
  arrow_dir <- file.path(tempdir(), "test_arrow_skip")

  # Create snapshot structure
  sources_dir <- file.path(snapshot_dir, "data", "sources", "part_000")
  dir.create(sources_dir, recursive = TRUE, showWarnings = FALSE)

  test_sources <- '{"id":"https://openalex.org/S1","display_name":"Test Journal"}'
  gz_file <- file.path(sources_dir, "test.gz")
  gz_con <- gzfile(gz_file, "w")
  writeLines(test_sources, gz_con)
  close(gz_con)

  # Create existing output directory
  output_dir <- file.path(arrow_dir, "sources")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Run conversion - should warn about existing directory
  expect_warning(
    snapshot_to_parquet(
      snapshot_dir = snapshot_dir,
      arrow_dir = arrow_dir,
      data_sets = "sources"
    ),
    "Skipping"
  )

  # Clean up
  unlink(snapshot_dir, recursive = TRUE)
  unlink(arrow_dir, recursive = TRUE)
})

testthat::test_that("snapshot_to_parquet handles works with large JSON", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")

  # Create temporary directories
  snapshot_dir <- file.path(tempdir(), "test_snapshot_works")
  arrow_dir <- file.path(tempdir(), "test_arrow_works")

  # Create works directory structure
  works_dir <- file.path(snapshot_dir, "data", "works", "part_000")
  dir.create(works_dir, recursive = TRUE, showWarnings = FALSE)

  # Create test works data
  test_works <- c(
    '{"id":"https://openalex.org/W1","doi":"https://doi.org/10.1000/test1","title":"Paper 1"}',
    '{"id":"https://openalex.org/W2","doi":"https://doi.org/10.1000/test2","title":"Paper 2"}'
  )

  gz_file <- file.path(works_dir, "test.gz")
  gz_con <- gzfile(gz_file, "w")
  writeLines(test_works, gz_con)
  close(gz_con)

  # Ensure clean output directory
  unlink(arrow_dir, recursive = TRUE)

  # Run conversion for works (should use maximum_object_size)
  expect_message(
    snapshot_to_parquet(
      snapshot_dir = snapshot_dir,
      arrow_dir = arrow_dir,
      data_sets = "works"
    ),
    "Processing works"
  )

  # Verify output
  output_dir <- file.path(arrow_dir, "works")
  expect_true(dir.exists(output_dir))

  parquet_files <- list.files(output_dir, pattern = "\\.parquet$", full.names = TRUE)
  expect_true(length(parquet_files) > 0)

  result <- arrow::read_parquet(parquet_files[1])
  expect_equal(nrow(result), 2)
  expect_true("id" %in% names(result))
  expect_true("doi" %in% names(result))

  # Clean up
  unlink(snapshot_dir, recursive = TRUE)
  unlink(arrow_dir, recursive = TRUE)
})
