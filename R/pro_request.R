#' `openalexR::oa_request()` with additional argument
#'
#' This function adds one argument to `openalexR::oa_request()`, namely
#' `output`. When specified, all return values from OpenAlex will be saved as
#' json files in that directory and the return value is the directory of the
#' json files.
#'
#' For the documentation please see `openalexR::oa_request()`
#' If query_url is a list, the function is called for each element of the list in parallel
#' using a maximum of `workers` parallel R sessions. The results from the individual URLs
#' in the list are returned in a folder named after the names of the list elements in the
#' `output` folder.
#'
#' When starting the download, a file `00_in.progress` which is deleted upon completion.
#'
#' @param query_url The URL of the API query or a list of URLs returned from `pro_query()`.
#' @param pages The number of pages to be downloaded. The default is set to
#'   0, which would be 2,000,000 works. It is recommended to not increase it
#'   beyond 10000 due to server load and to use the snapshot instead. If `NULL`,
#'   all pages will be downloaded. Default: 10000.
#' @param output directory where the JSON files are saved. Default is a
#'   temporary directory. If `NULL`, the return value from call to
#'   `openalexR::oa_request()` with all the arguments is returned
#' @param overwrite Logical. If `TRUE`, `output` will be deleted if it already
#'   exists.
#' @param mailto The email address of the user.
#' @param api_key The API key of the user.
#' @param workers Number of parallel workers to use if `query_url` is a list. Defaults to 1.
#' @param verbose Logical indicating whether to show verbose messages.
#' @param count_only return count only as a named numeric vector or list.
#' @param error_log location of error log of API calls. (default: `NULL` (none)).
#'
#' @return If `count_only` is `FALSE` (the default) the complete path to the expanded and
#'   normalized `output`. If `count_only` is `TRUE`, a named numeric vector with the count
#'   of the works from the specified query_url(s).
#'
#' @md
#'
#' @importFrom utils tail packageVersion
#' @importFrom httr2 req_url_query req_perform resp_body_json resp_body_string
#' @importFrom future plan multisession sequential
#' @importFrom future.apply future_lapply
#'
#' @export
pro_request <- function(
  query_url,
  pages = 10000,
  output = NULL,
  overwrite = FALSE,
  mailto = Sys.getenv("openalexPro.email"),
  api_key = Sys.getenv("openalexPro.apikey"),
  workers = 1,
  verbose = FALSE,
  count_only = FALSE,
  error_log = NULL
) {
  if (!is.null(error_log)) {
    message("error log file: ", error_log)
  }

  # ---------------------------------------------------------------------------
  # LIST METHOD: multiple queries -> futures
  # ---------------------------------------------------------------------------
  if (is.list(query_url)) {
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)

    if (workers > 1) {
      future::plan(future::multisession, workers = workers)
    } else {
      future::plan(future::sequential)
    }

    result <- future.apply::future_lapply(
      seq_along(query_url),
      function(i) {
        nm <- names(query_url)[i]
        if (is.null(nm) || identical(nm, "")) {
          nm <- paste0("query_", i)
        }
        pro_request(
          query_url = query_url[[i]],
          pages = pages,
          output = if (is.null(output)) NULL else file.path(output, nm),
          overwrite = FALSE,
          mailto = mailto,
          api_key = api_key,
          verbose = verbose,
          count_only = count_only,
          error_log = error_log
        )
      },
      future.seed = TRUE
    )

    if (count_only) {
      out <- unlist(result, use.names = FALSE)
      names(out) <- if (is.null(names(query_url))) {
        paste0("query_", seq_along(query_url))
      } else {
        names(query_url)
      }
      return(out)
    } else {
      return(output)
    }
  }

  # ---------------------------------------------------------------------------
  # SCALAR METHOD: single query
  # ---------------------------------------------------------------------------
  if (count_only) {
    out <- pro_count(
      query_url = query_url,
      mailto = mailto,
      api_key = api_key
    )
    return(out)
  }

  # Argument Checks -----------------------------------------------------------
  if (is.null(output)) {
    stop("No `output` specified!")
  }

  if (dir.exists(output)) {
    if (!overwrite) {
      stop(
        "Directory ",
        output,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    }
    if (verbose) {
      message(
        "Deleting and recreating `",
        output,
        "` to avoid inconsistencies."
      )
    }
    unlink(output, recursive = TRUE)
  }

  # Preparations --------------------------------------------------------------
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  progress_file <- file.path(output, "00_in.progress")
  file.create(progress_file)
  success <- FALSE
  on.exit(
    {
      if (isTRUE(success)) {
        unlink(progress_file)
      }
    },
    add = TRUE
  )

  output <- normalizePath(output)

  if (grepl("group_by=", query_url, fixed = TRUE)) {
    page_prefix <- "group_by_page_"
  } else {
    page_prefix <- "results_page_"
  }

  # Base request with query and custom user agent
  req <- httr2::request(query_url) |>
    httr2::req_url_query(
      per_page = 200,
      cursor = "*",
      api_key = api_key
    ) |>
    httr2::req_user_agent(paste(
      "openalexPro v",
      packageVersion("openalexPro"),
      " (mailto:",
      mailto,
      ")"
    ))

  # Initialize results and page counter
  page <- 1L

  # First request to inspect meta
  resp <- api_call(
    req,
    error_log = error_log
  )

  data <- resp |>
    httr2::resp_body_json()

  single_record <- is.null(data$meta)
  if (single_record) {
    page_prefix <- "single_"
  }

  # SINGLE-RECORD CASE --------------------------------------------------------
  if (single_record) {
    resp |>
      httr2::resp_body_string() |>
      writeLines(
        con = file.path(
          output,
          paste0(page_prefix, "1.json")
        )
      )
    success <- TRUE
    return(output)
  }

  # PAGINATED CASE ------------------------------------------------------------
  repeat {
    if (!is.null(pages) && page > pages) {
      break
    }

    if (verbose) {
      message("Downloading page ", page)
      message("URL: ", req$url)
    }

    resp <- api_call(
      req,
      error_log = error_log
    )

    data <- httr2::resp_body_json(resp)

    # grouping returns at the moment a last page with no groups - this must
    # not be saved!
    if (isTRUE(data$meta$groups_count == 0)) {
      break
    }

    resp |>
      httr2::resp_body_string() |>
      writeLines(
        con = file.path(
          output,
          paste0(page_prefix, page, ".json")
        )
      )

    if (is.null(data$meta$next_cursor)) {
      break
    }

    req <- req |>
      httr2::req_url_query(cursor = data$meta$next_cursor)

    page <- page + 1L
  }

  success <- TRUE

  output
}
