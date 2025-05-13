library(testthat)

testthat::test_that("jq_check throws an error when jq is not installed", {
  # Temporarily change the PATH to a directory that doesn't contain jq
  old_path <- Sys.getenv("PATH")
  Sys.setenv(PATH = "/tmp")

  expect_snapshot(error = TRUE, {
    jq_check()
  })

  # Restore the original PATH
  Sys.setenv(PATH = old_path)
})

testthat::test_that("jq_check returns TRUE when jq is installed", {
  # Check if jq is installed
  if (Sys.which("jq") != "") {
    expect_snapshot({
      jq_check()
    })
  } else {
    skip("jq is not installed, skipping test")
  }
})
