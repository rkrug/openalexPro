library(testthat)


# group_by ---------------------------------------------------------------

output_json <- file.path(tempdir(), "group_by_json")
output_jsonl <- file.path(tempdir(), "group_by_jsonl")
output_parquet <- file.path(tempdir(), "group_by_parquet")

unlink(output_json, recursive = TRUE, force = TRUE)
unlink(output_jsonl, recursive = TRUE, force = TRUE)
unlink(output_parquet, recursive = TRUE, force = TRUE)

test_that("pro_request `biodiversity` and group by type`", {
  # Define the API request
  output_json <- oa_query(
    title_and_abstract.search = "biodiversity",
    to_publication_date = "2010-01-01",
    group_by = "type"
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
    file.path(output_json, "group_by_page_1.json"),
    name = "json"
  )

  # Clean up temporary files
})


test_that("pro_request_jsonl `biodiversity` and group by type", {
  # Convert to parquet
  output_jsonl <- output_json |>
    pro_request_jsonl(
      output = output_jsonl,
      verbose = FALSE
    )

  # Check that the output file contains the expected data
  expect_snapshot_file(
    file.path(output_jsonl, "group_by_page_1.json"),
    name = "jsonl"
  )

  # Clean up temporary files
})

test_that("pro_request_jsonl_parquet `biodiversity` and group by type", {
  # Convert to parquet
  output_parquet <- output_jsonl |>
    pro_request_jsonl_parquet(
      output = output_parquet,
      verbose = FALSE
    )

  # Check that the output file exists
  expect_true(
    length(list.files(output_parquet, recursive = TRUE)) >= 1
  )

  # Get search results from openalexR::oa_fetch(output = "tibble") for comparison

  results_openalexR <- openalexR::oa_fetch(
    title_and_abstract.search = "biodiversity",
    to_publication_date = "2010-01-01",
    group_by = "type",
    output = "tibble",
    verbose = FALSE
  ) |>
    dplyr::arrange(key)

  results_openalexPro <- read_corpus(
    corpus = output_parquet,
    return_data = FALSE
  )

  # Check that the output file contains the expected data structure
  expect_snapshot({
    nrow(results_openalexPro)
    names(results_openalexPro) |>
      sort()

    results_openalexPro <- results_openalexPro |>
      dplyr::mutate(
        citation = NULL,
        page = NULL
      ) |>
      dplyr::arrange(key) |>
      dplyr::collect()

    print(results_openalexR)

    print(results_openalexPro)
  })

  expect_identical(
    results_openalexR,
    as.data.frame(results_openalexPro)
  )
})

unlink(output_json, recursive = TRUE, force = TRUE)
unlink(output_jsonl, recursive = TRUE, force = TRUE)
unlink(output_parquet, recursive = TRUE, force = TRUE)
