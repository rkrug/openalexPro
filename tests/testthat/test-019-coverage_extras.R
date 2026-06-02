# Tests targeting previously uncovered code paths in:
#   - oas_binary.R
#   - pro_validate_credentials.R
#   - prepare_snapshot.R
#   - sample_parquet_n.R

# --- oas_binary -------------------------------------------------------------

test_that("find_oas_binary uses explicit oas_bin when valid", {
  fake <- tempfile()
  file.create(fake)
  on.exit(unlink(fake), add = TRUE)
  expect_identical(find_oas_binary(fake), fake)
})

test_that("find_oas_binary uses package option as fallback", {
  fake <- tempfile()
  file.create(fake)
  withr::local_options(openalexPro.oas_bin = fake)
  on.exit(unlink(fake), add = TRUE)
  expect_identical(find_oas_binary(), fake)
})

test_that("find_oas_binary aborts with a helpful message when nothing resolves", {
  withr::local_options(openalexPro.oas_bin = NULL)
  withr::local_envvar(PATH = "")
  expect_error(find_oas_binary(oas_bin = NULL), "openalex-snapshot")
})

test_that("run_oas aborts when the binary exits non-zero", {
  # /usr/bin/false (or `false`) exits 1 on every platform we run CI on
  false_bin <- Sys.which("false")
  skip_if(false_bin == "", "`false` binary not available")
  expect_error(
    run_oas(args = character(), oas_bin = unname(false_bin)),
    "failed"
  )
})

# --- pro_validate_credentials ----------------------------------------------

test_that("pro_validate_credentials returns FALSE for an empty key", {
  # NULL key: pro_rate_limit_status() returns FALSE without making an API call.
  expect_message(
    res <- pro_validate_credentials(api_key = NULL),
    "Testing:"
  )
  expect_false(res)
})

test_that("pro_validate_credentials with show_credentials prints the key", {
  expect_message(
    pro_validate_credentials(api_key = "abc123", show_credentials = TRUE),
    "abc123"
  )
})

# --- prepare_snapshot -------------------------------------------------------

test_that("prepare_snapshot copies the Makefile to a target directory", {
  dest <- tempfile("prep_snap_")
  on.exit(unlink(dest, recursive = TRUE, force = TRUE), add = TRUE)

  suppressMessages({
    out <- prepare_snapshot(path = dest)
  })

  expect_true(file.exists(out))
  expect_identical(basename(out), "Makefile")
})

test_that("prepare_snapshot does not overwrite without overwrite = TRUE", {
  dest <- tempfile("prep_snap_no_ow_")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE, force = TRUE), add = TRUE)

  suppressMessages(prepare_snapshot(path = dest))

  makefile <- file.path(dest, "Makefile")
  writeLines("# sentinel", makefile)
  suppressMessages(prepare_snapshot(path = dest, overwrite = FALSE))
  expect_identical(readLines(makefile, n = 1L), "# sentinel")

  suppressMessages(prepare_snapshot(path = dest, overwrite = TRUE))
  expect_false(identical(readLines(makefile, n = 1L), "# sentinel"))
})

# --- sample_parquet_n ------------------------------------------------------

test_that("sample_parquet_n validates its inputs", {
  expect_error(sample_parquet_n(path = NA_character_, n = 5),
               "non-missing character scalar")
  expect_error(sample_parquet_n(path = "x", n = NA),
               "non-missing numeric")
  expect_error(sample_parquet_n(path = "x", n = 0),
               "positive integer")
  expect_error(sample_parquet_n(path = "x", n = 5, seed = NA),
               "non-missing numeric")
  expect_error(sample_parquet_n(path = "x", n = 5, select = character()),
               "non-empty character vector")
})

test_that("sample_parquet_n samples from a temporary parquet file", {
  skip_if_not_installed("arrow")
  pq <- tempfile(fileext = ".parquet")
  on.exit(unlink(pq), add = TRUE)
  arrow::write_parquet(data.frame(id = 1:50, x = letters[1:50 %% 26 + 1]), pq)

  res <- sample_parquet_n(path = pq, n = 10L, seed = 42L)
  expect_s3_class(res, "data.frame")
  expect_lte(nrow(res), 10L)
  expect_setequal(names(res), c("id", "x"))

  sub <- sample_parquet_n(path = pq, n = 5L, seed = 1L, select = "id")
  expect_identical(names(sub), "id")
})

test_that("sample_parquet_n reuses a supplied DBI connection", {
  skip_if_not_installed("arrow")
  pq <- tempfile(fileext = ".parquet")
  on.exit(unlink(pq), add = TRUE)
  arrow::write_parquet(data.frame(id = 1:20), pq)

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  res <- sample_parquet_n(path = pq, n = 5L, con = con)
  expect_s3_class(res, "data.frame")
  # connection should still be usable
  expect_true(DBI::dbIsValid(con))
})
