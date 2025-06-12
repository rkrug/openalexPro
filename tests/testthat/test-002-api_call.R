library(testthat)

test_that("api_call returns response object on success (200)", {
  vcr::use_cassette("api_call_200", {
    req <- httr2::request("https://api.openalex.org/works/W4234567890")
    resp <- api_call(req)
    expect_equal(httr2::resp_status(resp), 200)
  })
})

# test_that("api_call stops on Request Line too large (400)", {
#   vcr::use_cassette("api_call_400", {
#     req <- httr2::request(
#       "https://api.openalex.org/works?filter=title.search:verylongtitle"
#     )
#     expect_error(api_call(req), "HTTP status 400 Request Line is too large")
#   })
# })

# test_that("api_call stops on Too Many Requests (429)", {
#   vcr::use_cassette("api_call_429", {
#     req <- httr2::request("https://api.openalex.org/works/W4234567890")
#     # Simulate a 429 response by modifying the request headers
#     req$headers[["x-ratelimit-remaining"]] <- "0"
#     expect_error(api_call(req), "HTTP status 429 Too Many Requests")
#   })
# })

# test_that("api_call stops on Service Unavailable (503)", {
#   vcr::use_cassette("api_call_503", {
#     req <- httr2::request("https://api.openalex.org/works/INVALID")
#     # Simulate a 503 response
#     mockery::stub(api_call, "httr2::req_perform", function(...) {
#       list(status_code = 503, content = "<title>Service Unavailable</title>")
#     })
#     expect_error(
#       api_call(req),
#       paste0(
#           "Service Unavailable.\n",
#           "Please try setting `per_page = 25` in your function call!")
#     )
#     mockery::unstub(api_call, "httr2::req_perform")
#   })
# })

# test_that("api_call stops on generic error (>= 400)", {
#   vcr::use_cassette("api_call_404", {
#     req <- httr2::request("https://api.openalex.org/works/INVALID")
#     expect_error(api_call(req), "OpenAlex API request failed \\[404\\]")
#   })
# })
