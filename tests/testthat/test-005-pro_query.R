# tests/testthat/test-pro-vs-oa-query.R
testthat::test_that("opt_filter_names returns value", {
  testthat::local_edition(3)
  # vcr::local_cassette("opt_filter_names")
  testthat::expect_snapshot_value(opt_filter_names(), style = "json2")
})

testthat::test_that("opt_select_fields returns value", {
  testthat::local_edition(3)
  # vcr::local_cassette("opt_select_fields")
  testthat::expect_snapshot_value(opt_select_fields(), style = "json2")
})

testthat::test_that("pro_query and legacy query return identical URLs (search + filters)", {
  # same inputs for both
  entity <- "works"
  search <- "biodiversity"
  # filters passed via ... for both (oa_query supports ... as well)
  filters <- list(
    from_publication_date = "2020-01-01",
    language = c("en", "de"),
    type = "article"
  )
  # select: legacy passes via options$select; pro_query via select=
  sel <- c("ids", "title", "publication_year")
  opts <- list(per_page = 5, sort = "cited_by_count:desc")

  # build URLs
  url_legacy <- do.call(
    openalexR::oa_query,
    c(
      list(
        entity = entity,
        search = search,
        options = c(list(select = sel), opts)
      ),
      filters
    )
  )

  url_pro <- do.call(
    pro_query,
    c(
      list(
        entity = entity,
        search = search,
        select = sel,
        options = opts
      ),
      filters
    )
  )

  testthat::expect_type(url_legacy, "character")
  testthat::expect_type(url_pro, "character")
  testthat::expect_identical(url_pro, url_legacy)
})

testthat::test_that("pro_query and legacy query return identical URLs (single id)", {
  entity <- "works"
  identifier <- "W1775749144"
  sel <- c("ids", "title")

  url_legacy <- openalexR::oa_query(
    entity = entity,
    identifier = identifier,
    options = list(select = sel)
  )

  url_pro <- pro_query(
    entity = entity,
    id = identifier,
    select = sel
  )

  testthat::expect_identical(url_pro, url_legacy)
})

# testthat::test_that("pro_query and legacy query return identical URLs (multiple_id via ids.openalex filter)", {
#   entity <- "works"
#   ids <- c("W2741809807", "W2092304384")
#   # Both functions should transform vector ids into the ids.openalex filter when multiple_id = TRUE

#   url_legacy <- openalexR::oa_query(
#     entity = entity,
#     multiple_id = TRUE,
#     identifier = ids
#   )

#   url_pro <- pro_query(
#     entity = entity,
#     multiple_id = TRUE,
#     id = ids
#   )

#   testthat::expect_identical(url_pro, url_legacy)
# })

# tests/testthat/test-pro-vs-oa-query-grouping.R

testthat::test_that("pro_query and legacy query return identical URLs with grouping", {
  entity <- "works"
  search <- "biodiversity"
  group <- "type"
  filters <- list(
    from_publication_date = "2020-01-01",
    language = "en"
  )
  opts <- list(per_page = 50)

  # build URL with legacy fn
  url_legacy <- do.call(
    openalexR::oa_query,
    c(
      list(
        entity = entity,
        search = search,
        group_by = group,
        options = opts
      ),
      filters
    )
  )

  # build URL with pro_query
  url_pro <- do.call(
    pro_query,
    c(
      list(
        entity = entity,
        search = search,
        group_by = group,
        options = opts
      ),
      filters
    )
  )

  testthat::expect_type(url_legacy, "character")
  testthat::expect_type(url_pro, "character")
  testthat::expect_identical(url_pro, url_legacy)
})


# small helper (internal) -------------------------------------------------
`%||%` <- function(a, b) if (is.null(a)) b else a
