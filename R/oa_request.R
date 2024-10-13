#' `openalexR::oa_request()` with additional argument
#'
#' This function adds one argument to `openalexR::oa_request()`, namely `json_dir`.
#' When specified, all return values from OpenAlex will be saved as jaon files in
#' that directory and the return value is the directory of the json files.
#'
#' For the documentation please see `openalexR::oa_request()`
#'
#' @param query_url The URL of the API query.
#' @param per_page The number of items to be returned per page. Defaults to 200.
#' @param paging The type of paging. Possible values are "page" and "cursor".
#' @param pages The number of pages to be downloaded. If `NULL`, all pages will be downloaded.
#' @param count_only Logical indicating whether to return only the count of the items returned by the query.
#' @param mailto The email address of the user. See `openalexR::oa_email()`.
#' @param api_key The API key of the user. See `openalexR::oa_apikey()`.
#' @param verbose Logical indicating whether to show a progress bar.
#' @param json_dir directory where the JSON files are saved. Default is a temporary directory
#'
#' @return If `json_dir` is `NULL`, the return value from call to `openalexR::oa_request()`,
#'   otherwise the complete path to the expanded and normalized `json_dir`.
#'
#' @md
#'
#' @importFrom openalexR oa_email oa_apikey oa_request oa_fetch oa_snowball
#' @importFrom utils tail
#'
#' @export
#'
oa_request <- function(
    query_url,
    per_page = 200,
    paging = "cursor",
    pages = NULL,
    count_only = FALSE,
    mailto = oa_email(),
    api_key = oa_apikey(),
    verbose = FALSE,
    json_dir = tempfile(fileext = ".json_dir")) {
  if (!is.null(json_dir)) {
    message("Deleting and recreating `", json_dir, "` to avoid inconsistencies.")
    if (dir.exists(json_dir)) {
      unlink(json_dir, recursive = TRUE)
    }
    dir.create(json_dir, recursive = TRUE)
  }


  # https://httr.r-lib.org/articles/api-packages.html#set-a-user-agent
  ua <- httr::user_agent("https://github.com/ropensci/openalexR/")

  # building query...
  is_group_by <- grepl("group_by", query_url)
  if (is_group_by) {
    result_name <- "group_by"
    query_ls <- list()
  } else {
    result_name <- "results"
    query_ls <- list("per-page" = 1)
  }

  if (!is.null(mailto)) {
    if (openalexR:::isValidEmail(mailto)) {
      query_ls[["mailto"]] <- mailto
    } else {
      message(mailto, " is not a valid email address")
    }
  }

  # first, download info about n. of items returned by the query
  res <- api_request(query_url, ua, query = query_ls, api_key = api_key)

  if (!is.null(res$meta)) {
    ## return only item counting
    if (count_only) {
      return(res$meta)
    }
  } else {
    return(res)
  }

  # Setting items per page
  query_ls[["per-page"]] <- per_page

  if (is_group_by) {
    data <- vector("list")
    res <- NULL
    i <- 1
    next_page <- openalexR:::get_next_page("cursor", i, res)
    if (verbose) cat("\nDownloading groups...\n|")
    while (!is.null(next_page)) {
      if (verbose) cat("=")
      Sys.sleep(1 / 10)
      query_ls[[paging]] <- next_page
      res <- api_request(query_url, ua, query = query_ls, json_dir = json_dir)
      if (is.null(json_dir)) {
        data <- c(data, res[[result_name]])
      }
      i <- i + 1
      next_page <- openalexR:::get_next_page("cursor", i, res)
    }
    cat("\n")
    return(data)
  }

  n_items <- res$meta$count
  n_pages <- ceiling(n_items / per_page)

  ## number of pages
  if (is.null(pages)) {
    pages <- seq.int(n_pages)
  } else {
    pages <- pages[pages <= n_pages]
    n_pages <- length(pages)
    n_items <- min(n_items - per_page * (utils::tail(pages, 1) - n_pages), per_page * n_pages)
    message("Using basic paging...")
    paging <- "page"
  }

  if (n_items <= 0 || n_pages <= 0) {
    warning("No records found!")
    return(list())
  }

  pg_plural <- if (n_pages > 1) " pages" else " page"

  if (verbose) {
    message(
      "Getting ", n_pages, pg_plural, " of results",
      " with a total of ", n_items, " records..."
    )
    pb <- openalexR:::oa_progress(n = n_pages, text = "OpenAlex downloading")
  }

  # Activation of cursor pagination
  data <- vector("list", length = n_pages)
  res <- NULL
  for (i in pages) {
    if (verbose) pb$tick()
    Sys.sleep(1 / 10)
    next_page <- openalexR:::get_next_page(paging, i, res)
    query_ls[[paging]] <- next_page
    res <- api_request(query_url, ua, query = query_ls, json_dir = json_dir)
    # if (is.null(json_dir)) {
    #   if (!is.null(res[[result_name]])) data[[i]] <- res[[result_name]]
    # }
  }

  # if (is.null(json_dir)) {
  #   data <- unlist(data, recursive = FALSE)

  #   if (grepl("filter", query_url) && grepl("works", query_url)) {
  #     truncated <- unlist(openalexR:::truncated_authors(data))
  #     if (length(truncated)) {
  #       truncated <- openalexR:::shorten_oaid(truncated)
  #       warning(
  #         "\nThe following work(s) have truncated lists of authors: ",
  #         paste(truncated, collapse = ", "),
  #         ".\nQuery each work separately by its identifier to get full list of authors.\n",
  #         "For example:\n  ",
  #         paste0(
  #           "lapply(c(\"",
  #           paste(utils::head(truncated, 2), collapse = "\", \""),
  #           "\"), \\(x) oa_fetch(identifier = x))"
  #         ),
  #         "\nDetails at https://docs.openalex.org/api-entities/authors/limitations."
  #       )
  #     }
  #   }
  # } else {
  data <- normalizePath(json_dir)
  # }
  ##
  return(data)
}
