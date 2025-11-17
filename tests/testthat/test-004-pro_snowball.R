library(testthat)
library(vdiffr)
suppressPackageStartupMessages(library(dplyr))

output_dir <- file.path(tempdir(), "snowball")
unlink(output_dir, recursive = TRUE, force = TRUE)

test_that("pro_snowball", {
  # openalexR
  vcr::local_cassette("oa_snowball")
  results_openalexR <- openalexR::oa_snowball(
    identifier = c("W3045921891", "W3046863325"),
    verbose = FALSE
  )

  results_openalexR$nodes <- results_openalexR$nodes |>
    dplyr::arrange(
      dplyr::desc(oa_input),
      id
    )

  results_openalexR$edges <- results_openalexR$edges |>
    dplyr::arrange(
      from,
      to
    )

  # openalexPro
  vcr::local_cassette("pro_snowball")
  output_dir <- pro_snowball(
    identifier = c("W3045921891", "W3046863325"),
    output = output_dir,
    verbose = FALSE
  )

  results_openalexPro <- read_snowball(
    file.path(output_dir),
    return_data = TRUE,
    shorten_ids = TRUE,
    edge_type = "core"
  )

  # Comparison

  nodes_diff <- dplyr::anti_join(
    results_openalexPro$nodes |> dplyr::select(id, oa_input),
    results_openalexR$nodes |> dplyr::select(id, oa_input),
    by = dplyr::join_by(id, oa_input)
  )

  edges_diff <- dplyr::anti_join(
    results_openalexPro$edges |> dplyr::filter(edge_type == "core"),
    results_openalexR$edges,
    by = dplyr::join_by(from, to)
  )

  # Check that the output file contains the expected data structure
  expect_snapshot({
    names(results_openalexPro)

    nrow(results_openalexPro$nodes)
    names(results_openalexPro$nodes) |>
      sort()

    nrow(results_openalexPro$edges)
    names(results_openalexPro$edges) |>
      sort()

    read_snowball(
      file.path(output_dir),
      return_data = TRUE,
      shorten_ids = TRUE,
      edge_type = "core"
    )

    read_snowball(
      file.path(output_dir),
      return_data = TRUE,
      shorten_ids = TRUE,
      edge_type = "extended"
    )

    read_snowball(
      file.path(output_dir),
      return_data = TRUE,
      shorten_ids = TRUE,
      edge_type = c("extended", "core")
    )

    read_snowball(
      file.path(output_dir),
      return_data = TRUE,
      shorten_ids = TRUE,
      edge_type = "outside"
    )

    results_openalexPro$nodes |>
      dplyr::select(id, oa_input, relation) |>
      dplyr::arrange(oa_input, relation) |>
      dplyr::collect() |>
      print(n = Inf)

    results_openalexPro$edges |>
      dplyr::arrange(edge_type, from, to) |>
      dplyr::collect() |>
      print(n = Inf)

    print(nodes_diff, n = Inf)
    print(edges_diff, n = Inf)
  })

  # Check nodes
  expect_true(
    nrow(nodes_diff) == 0
  )

  # Check edges
  expect_true(
    nrow(edges_diff) == 0
  )

  # Check that the output file contains the expected data
  # expect_snapshot_file(file.path(output_dir, "results_page_1.json"))

  # Compare plot_snowball

  # plot_pro <- plot_snowball(snowball = results_openalexPro)
  # plot_r <- plot_snowball(snowball = results_openalexR)

  # test_that("snowball plots have visually not changed", {
  #   vdiffr::expect_doppelganger("Snowball-plot-Pro", plot_pro)
  #   vdiffr::expect_doppelganger("Snowball-plot-R", plot_r)
  # })

  # Assert that both plots look the same by giving them the same label
  # test_that("snowball plots are visually the same", {
  #   vdiffr::expect_doppelganger("Snowball-identical-plot", plot_pro)
  #   vdiffr::expect_doppelganger("Snowball-identical-plot", plot_r)
  # })
})

unlink(output_dir, recursive = TRUE, force = TRUE)
