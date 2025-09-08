test_that("extract_doi handles all `what` values correctly", {
  x <- c(
    "https://doi.org/10.5281/zenodo.1234567",
    "http://dx.doi.org/10.1000/XYZ123",
    "10.1234/example.doi",
    "This is a sentence without a DOI.",
    NA
  )

  # Expected outputs
  expected_doi <- c(
    "10.5281/zenodo.1234567",
    "10.1000/xyz123",
    "10.1234/example.doi",
    "", # fallback
    "" # fallback
  )

  expected_prefix <- c("10.5281", "10.1000", "10.1234", "", "")
  expected_resolver <- c("https://doi.org/", "http://dx.doi.org/", "", "", "")
  expected_suffix <- c("zenodo.1234567", "xyz123", "example.doi", "", "")

  # Test: full DOI extraction (default)
  expect_equal(
    extract_doi(x),
    expected_doi
  )

  # Test: prefix extraction
  expect_equal(
    extract_doi(x, what = "prefix"),
    expected_prefix
  )

  # Test: resolver extraction
  expect_equal(
    extract_doi(x, what = "resolver"),
    expected_resolver
  )

  # Test: suffix extraction
  expect_equal(
    extract_doi(x, what = "suffix"),
    expected_suffix
  )

  # Test: normalize = FALSE
  expect_equal(
    extract_doi(x, what = "doi", normalize = FALSE),
    c("10.5281/zenodo.1234567", "10.1000/XYZ123", "10.1234/example.doi", "", "")
  )

  # Test: non_doi_value = NA_character_
  expect_equal(
    extract_doi(x, non_doi_value = NA_character_),
    c("10.5281/zenodo.1234567", "10.1000/xyz123", "10.1234/example.doi", NA, NA)
  )

  # Test: non_doi_value = NULL
  expect_equal(
    extract_doi(x, non_doi_value = NULL),
    c("10.5281/zenodo.1234567", "10.1000/xyz123", "10.1234/example.doi")
  )

  # Test: non_doi_value = NULL
  expect_equal(
    extract_doi(x, what = "resolver", non_doi_value = NULL),
    c("https://doi.org/", "http://dx.doi.org/")
  )

  # Test: non_doi_value = NULL
  expect_equal(
    extract_doi(x, non_doi_value = "", normalize = TRUE),
    expected_doi
  )
})
