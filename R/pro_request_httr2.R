#' `openalexR::oa_request()` with additional argument
#'
#' This function adds one argument to `openalexR::oa_request()`, namely `json_dir`.
#' When specified, all return values from OpenAlex will be saved as jaon files in
#' that directory and the return value is the directory of the json files.
#'
#' For the documentation please see `openalexR::oa_request()`
#'
#' @param query_url The URL of the API query.
#' @param pages The number of pages to be downloaded. The default is set to 1000, which would be 2,000,000 works.
#'   It is recommended to not increase it beyond 1000 due to server load and to use the snapshot instead.
#'   If `NULL`, all pages will be downloaded.
#'   Default: 1000.
#' @param json_dir directory where the JSON files are saved. Default is a temporary directory. If `NULL`,
#'   the return value from call to `openalexR::oa_request()` with all the arguments is returned.
#' @params overwrite Logical. If `TRUE`, `json_dir` will be deleted if it already exists.
#' @param mailto The email address of the user. See `openalexR::oa_email()`.
#' @param api_key The API key of the user. See `openalexR::oa_apikey()`.
#' @param verbose Logical indicating whether to show verbose messages.
#' @param progress Logical default `TRUE` indicating whether to show a progress bar.
#'
#' @return If `json_dir` is `NULL`, the return value from call to `openalexR::oa_request()`,
#'   otherwise the complete path to the expanded and normalized `json_dir`.
#'
#' @md
#'
#' @importFrom openalexR oa_request
#' @importFrom utils tail
#'
#' @export
#'
pro_request_httr2 <- function(
  query_url,
  pages = 1000,
  json_dir = tempfile(fileext = ".json_dir"),
  overwrite = FALSE,
  mailto = oa_email(),
  api_key = oa_apikey(),
  verbose = FALSE,
  progress = TRUE
) {
  if (dir.exists(json_dir)) {
    if (!overwrite) {
      stop(
        "Directory ",
        json_dir,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    }
    if (verbose) {
      message(
        "Deleting and recreating `",
        json_dir,
        "` to avoid inconsistencies."
      )
    }
    unlink(json_dir, recursive = TRUE)
  }
  dir.create(json_dir, recursive = TRUE)

  json_dir <- normalizePath(json_dir)

  if (grepl("group_by=", query_url)) {
    page_prefix <- "group_by_page_"
  } else {
    page_prefix <- "results_page_"
  }

  # Created with help from chatGPT
  # Base request with query and custom user agent
  req <- httr2::request(query_url) |>
    httr2::req_url_query(
      per_page = 200,
      cursor = "*",
      mailto = email,
      api_key = api_key
    ) |>
    httr2::req_user_agent("https://github.com/rkrug/openalexPro")

  # Remove empty query parameters
  # req$url$query <- req$url$query[req$url$query != ""]

  # Initialize results and page counter
  page <- 1

  if (progress) {
    data <- req |>
      httr2::req_perform() |>
      httr2::resp_body_json()
    max_pages <- ceiling(data$meta$count / data$meta$per_page)
    # Create a progress bar
    pb <- txtProgressBar(min = 1, max = max_pages, style = 3)
  }

  # Pagination loop
  repeat {
    if (verbose) {
      message("Downloading page ", page)
      message("URL: ", req$url)
    }

    if (progress) {
      setTxtProgressBar(pb, page) # Update progress bar
    }

    resp <- httr2::req_perform(req)

    data <- httr2::resp_body_json(resp)

    ## grouping returns at the moment a last page with no groups - this must not be saved!
    if (data$meta$groups_count == 0) {
      break
    }

    resp |>
      httr2::resp_body_string() |>
      writeLines(
        con = file.path(json_dir, paste0(page_prefix, page, ".json"))
      )

    if (is.null(data$meta$next_cursor)) {
      break
    }

    # This is needed for groups as at the moment OpenAlex returns a final cursor page with no tresults
    # if (isTRUE(data$meta$groups_count == 200)) {
    #   break
    # }

    if (!is.null(pages)) {
      if (page > pages) break # Remove this to fetch all pages
    }

    req <- req |>
      httr2::req_url_query(cursor = data$meta$next_cursor)

    page <- page + 1
  }

  ###

  return(json_dir)
}
