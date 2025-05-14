library(testthat)
suppressPackageStartupMessages(library(dplyr))

output_dir <- file.path(tempdir(), "snowball")
unlink(output_dir, recursive = TRUE, force = TRUE)

test_that("pro_snowball", {
  # Convert to parquet
  output_dir <- pro_snowball(
    identifier = c("W3045921891", "W3046863325"),
    output = output_dir,
    verbose = FALSE
  )

  # Check that the output file contains the expected data structure
  expect_snapshot({
    x <- read_snowball(
      file.path(output_dir),
      return_data = FALSE
    )

    names(x)

    nrow(x$nodes)
    names(x$nodes) |>
      sort()

    nrow(x$edges)
    names(x$edges) |>
      sort()

    x$nodes |>
      dplyr::select(id, oa_input, relation) |>
      dplyr::arrange(oa_input, relation) |>
      dplyr::collect() |>
      print(n = Inf)

    x$edges |>
      dplyr::arrange(edge_type, from, to) |>
      dplyr::collect() |>
      print(n = Inf)
  })

  # Check that the output file contains the expected data
  # expect_snapshot_file(file.path(output_dir, "results_page_1.json"))
})

unlink(output_dir, recursive = TRUE, force = TRUE)
