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

  results_openalexR <- openalexR::oa_snowball(
    identifier = c("W3045921891", "W3046863325"),
    verbose = FALSE
  )

  results_openalexR$nodes <- results_openalexR$nodes |>
    dplyr::arrange(id) |>
    dplyr::mutate(
      id = paste0("https://openalex.org/", id)
    )

  results_openalexR$edges <- results_openalexR$edges |>
    dplyr::arrange(from, to) |>
    dplyr::mutate(
      from = paste0("https://openalex.org/", from),
      to = paste0("https://openalex.org/", to)
    )

  results_openalexPro <- read_snowball(
    file.path(output_dir),
    return_data = FALSE
  )

  results_openalexPro <- read_snowball(
    file.path(output_dir),
    return_data = TRUE
  )

  nodes_diff <- dplyr::anti_join(
    results_openalexPro$nodes |> dplyr::select(id, oa_input),
    results_openalexR$nodes |> dplyr::select(id, oa_input),
    by = dplyr::join_by(id, oa_input)
  )

  edges_diff <- dplyr::anti_join(
    results_openalexPro$edges |> dplyr::filter(edge_type == "core"),
    results_openalexR$edges,
    by = join_by(from, to)
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

    results_openalexPro$nodes |>
      dplyr::select(id, oa_input, relation) |>
      dplyr::arrange(oa_input, relation) |>
      dplyr::collect() |>
      print(n = Inf)

    results_openalexPro$edges |>
      dplyr::arrange(edge_type, from, to) |>
      dplyr::collect() |>
      print(n = Inf)

    print(nodes_diff)
    print(edges_diff)
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
})

unlink(output_dir, recursive = TRUE, force = TRUE)
