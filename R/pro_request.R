#' Fetch works from OpenAlex
#'
#' All returned values from OpenAlex will be saved as
#' json files in the `output` directory and the return value is the directory of the
#' json files.
#'
#' If query_url is a list, the function is called for each element of the list in parallel
#' using a maximum of `workers` parallel R sessions. The results from the individual URLs
#' in the list are returned in a folder named after the names of the list elements in the
#' `output` folder.
#'
#' When starting the download, a file `00_in.progress` which is deleted upon completion.
#'
#' @param query_url The URL of the API query or a list of URLs returned from `pro_query()`.
#' @param pages The number of pages to be downloaded. The default is set to
#'   10000, which would be 2,000,000 works. It is recommended to not increase it
#'   beyond 100000 due to server load and to use the snapshot instead. If `NULL`,
#'   all pages will be downloaded. Default: 100000.
#' @param output directory where the JSON files are saved. Default is a
#'   temporary directory. Needs to be specified.
#' @param overwrite Logical. If `TRUE`, `output` will be deleted if it already
#'   exists.
#' @param mailto The email address of the user.
#' @param api_key The API key of the user.
#' @param workers Number of parallel workers to use if `query_url` is a list. Defaults to 1.
#' @param verbose Logical indicating whether to show verbose messages.
#' @param progress Logical indicating whether to show a progress bar. Default `TRUE`.
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
#' @importFrom cli cli_progress_bar cli_progress_update cli_progress_done cli_alert_info
#' @importFrom progressr with_progress progressor handlers
#'
#' @export
pro_request <- function(
  query_url,
  pages = 100000,
  output = NULL,
  overwrite = FALSE,
  mailto = Sys.getenv("openalexPro.email"),
  api_key = Sys.getenv("openalexPro.apikey"),
  workers = 1,
  verbose = FALSE,
  progress = TRUE,
  count_only = FALSE,
  error_log = NULL
) {
  if (!is.null(error_log)) {
    message("error log file: ", error_log)
  }

  # ---------------------------------------------------------------------------
  # LIST METHOD: multiple queries -> futures with total-items progress
  # ---------------------------------------------------------------------------
  if (is.list(query_url)) {
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)

    if (workers > 1) {
      future::plan(future::multisession, workers = workers)
    } else {
      future::plan(future::sequential)
    }

    # Handle count_only case
    if (count_only) {
      result <- future.apply::future_lapply(
        seq_along(query_url),
        function(i) {
          pro_count(
            query_url = query_url[[i]],
            mailto = mailto,
            api_key = api_key
          )
        },
        future.seed = TRUE
      )
      out <- unlist(result, use.names = FALSE)
      names(out) <- if (is.null(names(query_url))) {
        paste0("query_", seq_along(query_url))
      } else {
        names(query_url)
      }
      return(out)
    }

    # Calculate total pages for progress bar
    if (progress) {
      cli::cli_alert_info("Fetching query counts...")
      counts <- vapply(
        query_url,
        function(url) {
          pro_count(url, mailto = mailto, api_key = api_key)$count
        },
        numeric(1)
      )

      per_page <- 200
      max_pages_per_query <- if (is.null(pages)) Inf else pages
      pages_per_query <- pmin(ceiling(counts / per_page), max_pages_per_query)
      total_pages <- sum(pages_per_query)
      cli::cli_alert_info("Total pages to download: {total_pages}")

      progressr::handlers("cli")
    } else {
      total_pages <- 1 # Dummy value when progress is disabled
    }

    # Run parallel downloads with progress
    # Note: auto_finish = FALSE prevents warnings when actual pages differ from estimate
    progressr::with_progress(
      {
        p <- if (progress) {
          progressr::progressor(steps = total_pages, auto_finish = FALSE)
        } else {
          NULL
        }

        result <- future.apply::future_lapply(
          seq_along(query_url),
          function(i) {
            nm <- names(query_url)[i]
            if (is.null(nm) || identical(nm, "")) {
              nm <- paste0("query_", i)
            }
            query_output <- if (is.null(output)) NULL else file.path(output, nm)

            fetch_query_pages(
              query_url = query_url[[i]],
              pages = pages,
              output = query_output,
              overwrite = FALSE,
              mailto = mailto,
              api_key = api_key,
              verbose = verbose,
              error_log = error_log,
              progressor = p
            )
          },
          future.seed = TRUE
        )
      },
      enable = progress
    )

    return(output)
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

  # Use helper function with cli progress for single query
  fetch_query_pages(
    query_url = query_url,
    pages = pages,
    output = output,
    overwrite = overwrite,
    mailto = mailto,
    api_key = api_key,
    verbose = verbose,
    error_log = error_log,
    progressor = NULL,
    use_cli_progress = progress
  )
}


#' Fetch pages for a single query (internal helper)
#'
#' @param query_url Single query URL
#' @param pages Max pages to download
#' @param output Output directory
#' @param overwrite Whether to overwrite existing output
#' @param mailto Email for API
#' @param api_key API key
#' @param verbose Show verbose messages
#' @param error_log Error log file path
#' @param progressor Optional progressr progressor for parallel progress
#' @param use_cli_progress Use cli progress bar (for sequential/scalar use)
#'
#' @return Output directory path
#' @keywords internal
#' @noRd
fetch_query_pages <- function(
  query_url,
  pages,
  output,
  overwrite,
  mailto,
  api_key,
  verbose,
  error_log,
  progressor = NULL,
  use_cli_progress = FALSE
) {
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

  # Initialize page counter
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
    if (!is.null(progressor)) {
      progressor()
    }
    success <- TRUE
    return(output)
  }

  # Calculate max_pages for cli progress bar
  max_pages <- NA_integer_
  if (!is.null(data$meta$count) && !is.null(data$meta$per_page)) {
    max_pages <- ceiling(data$meta$count / data$meta$per_page)
    if (!is.null(pages)) {
      max_pages <- min(max_pages, pages)
    }
  }

  # Start cli progress bar if requested (scalar mode only)
  show_cli_progress <- use_cli_progress && !is.na(max_pages)
  cli_progress_count <- 0L
  if (show_cli_progress) {
    cli::cli_progress_bar(
      total = max_pages,
      format = "Downloading {cli::pb_bar} {cli::pb_current}/{cli::pb_total} [{cli::pb_elapsed}]",
      clear = FALSE
    )
  }

  # PAGINATED CASE ------------------------------------------------------------
  # Save the first page (already fetched above for meta inspection)
  resp |>
    httr2::resp_body_string() |>
    writeLines(
      con = file.path(
        output,
        paste0(page_prefix, page, ".json")
      )
    )

  # Update progress for first page
  if (!is.null(progressor)) {
    progressor()
  } else if (show_cli_progress && cli_progress_count < max_pages) {
    cli_progress_count <- cli_progress_count + 1L
    cli::cli_progress_update(force = TRUE)
  }

  # Continue with remaining pages if needed
  while (!is.null(data$meta$next_cursor)) {
    page <- page + 1L

    if (!is.null(pages) && page > pages) {
      break
    }

    req <- req |>
      httr2::req_url_query(cursor = data$meta$next_cursor)

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

    # Update progress (only if we haven't reached the total yet)
    if (!is.null(progressor)) {
      progressor()
    } else if (show_cli_progress && cli_progress_count < max_pages) {
      cli_progress_count <- cli_progress_count + 1L
      cli::cli_progress_update()
    }
  }

  # Only call done if progress bar wasn't auto-closed by reaching total
  if (show_cli_progress && cli_progress_count < max_pages) {
    cli::cli_progress_done()
  }

  success <- TRUE

  output
}
