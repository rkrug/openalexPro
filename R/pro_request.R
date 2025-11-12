#' `openalexR::oa_request()` with additional argument
#'
#' This function adds one argument to `openalexR::oa_request()`, namely
#' `output`. When specified, all return values from OpenAlex will be saved as
#' jaon files in that directory and the return value is the directory of the
#' json files.
#'
#' For the documentation please see `openalexR::oa_request()`
#' If query_url is a list, the function is called for each element of the list in parallel
#' using a maximum of `workers` parallel R sessions. The results from the individual URLs
#' in the list are returned in a folder named after the names of the list elements in the
#' `output` folder.
#' @param query_url The URL of the API query or a list of URLs returned from `pro_query()`.
#' @param pages The number of pages to be downloaded. The default is set to
#'   1000, which would be 2,000,000 works. It is recommended to not increase it
#'   beyond 1000 due to server load and to use the snapshot instead. If `NULL`,
#'   all pages will be downloaded. Default: 1000.
#' @param output directory where the JSON files are saved. Default is a
#'   temporary directory. If `NULL`, the return value from call to
#'   `openalexR::oa_request()` with all the arguments is returned
#' @param overwrite Logical. If `TRUE`, `output` will be deleted if it already
#'   exists.
#' @param mailto The email address of the user. See `oap_mail()`.
#' @param api_key The API key of the user. See `oap_apikey`.
#' @param workers Number of parallel workers to use if `query_url` is a list. Defaults to 1.
#' @param verbose Logical indicating whether to show verbose messages.
#' @param progress Logical default `TRUE` indicating whether to show a progress
#'   bar.
#' @param count_only return count only as a named numeric vector or list.
#' @param error_log location of error log of API calls. (default: `NULL` (none)).
#'
#' @return If `count_only` is `FALSE` (the default) the complete path to the expanded and
#'   normalized `output`. If `count_only` is `TRUE`, a named numeric vector with the count
#'   of the works from the specified query_url(s).
#'
#' @md
#'
#' @importFrom utils tail
#' @importFrom httr2 req_url_query req_perform resp_body_json resp_body_string
#' @importFrom utils setTxtProgressBar txtProgressBar packageVersion
#' @importFrom future plan multisession sequential
#' @importFrom future.apply future_lapply
#'
#' @export
#'
pro_request <- function(
  query_url,
  pages = 1000,
  output = NULL,
  overwrite = FALSE,
  mailto = oap_mail(),
  api_key = oap_apikey,
  workers = 1,
  verbose = FALSE,
  progress = TRUE,
  count_only = FALSE,
  error_log = NULL
) {
  # Call for each element if query_url is a list ---------------------------
  if (!is.null(error_log)) {
    message("error log file: ", error_log)
  }

  if (is.list(query_url)) {
    # for (i in seq_along(query_url)) {
    #   pro_request(
    #     query_url = query_url[[i]],
    #     pages = pages,
    #     output = output,
    #     overwrite = FALSE,
    #     mailto = mailto,
    #     api_key = api_key,
    #     verbose = verbose,
    #     progress = progress
    #   )
    future::plan(future::multisession, workers = workers)
    on.exit(future::plan(future::sequential), add = TRUE)

    result <- future.apply::future_lapply(
      seq_along(query_url),
      function(i) {
        nm <- names(query_url)[i]
        if (is.null(nm)) {
          nm <- paste0("query_", i)
        }
        pro_request(
          query_url = query_url[[i]],
          pages = pages,
          output = file.path(output, nm),
          overwrite = FALSE,
          mailto = mailto,
          api_key = api_key,
          verbose = verbose,
          progress = progress,
          count_only = count_only,
          error_log = error_log
        )
      },
      future.seed = TRUE
    )
    if (count_only) {
      output <- do.call(result, what = rbind)
      rownames(output) <- names(query_url)
    }
    return(output)
  } else {
    if (count_only) {
      output <- pro_count(
        query_url = query_url,
        mailto = mailto,
        api_key = api_key
      )
    } else {
      # Argument Checks --------------------------------------------------------

      if (is.null(output)) {
        stop("No `output` output specified!")
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

      # Preparations -----------------------------------------------------------

      dir.create(output, recursive = TRUE, showWarnings = FALSE)

      output <- normalizePath(output)

      if (is.function(api_key)) {
        api_key <- api_key()
      }
      if (is.null(api_key)) {
        api_key <- ""
      }

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
          api_key = api_key
        ) |>
        httr2::req_user_agent(paste(
          "openalexPro v",
          packageVersion("openalexPro"),
          " (mailto:",
          mailto,
          ")"
        ))

      # Remove empty query parameters
      # req$url$query <- req$url$query[req$url$query != ""]

      # Initialize results and page counter
      page <- 1

      # resp <- httr2::req_perform(req)
      resp <- api_call(
        req,
        error_log = error_log
      )

      data <- resp |>
        httr2::resp_body_json()

      if (is.null(data$meta)) {
        single_record <- TRUE
        page_prefix <- "single_"
        progress <- FALSE
      } else {
        single_record <- FALSE
        if (progress) {
          max_pages <- ceiling(data$meta$count / data$meta$per_page)
          # Create a progress bar
          pb <- txtProgressBar(min = 0, max = max_pages, style = 3)
        }
      }

      if (single_record) {
        page <- 1
        resp |>
          httr2::resp_body_string() |>
          writeLines(
            con = file.path(
              output,
              paste0(page_prefix, page, ".json")
            )
          )
      } else {
        # Pagination loop
        repeat {
          if (!is.null(pages)) {
            if (page > pages) break # Remove this to fetch all pages
          }

          if (verbose) {
            message("\nDownloading page ", page)
            message("URL: ", req$url)
          }

          if (progress) {
            setTxtProgressBar(pb, page) # Update progress bar
          }

          # resp <- httr2::req_perform(req)
          resp <- api_call(
            req,
            error_log = error_log
          )

          data <- httr2::resp_body_json(resp)

          ## grouping returns at the moment a last page with no groups - this must
          ## not be saved!
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

          # This is needed for groups as at the moment OpenAlex returns a final
          # cursor page with no tresults if (isTRUE(data$meta$groups_count == 200))
          # { break }

          req <- req |>
            httr2::req_url_query(cursor = data$meta$next_cursor)

          page <- page + 1
        }
      }
      ###
    }
    return(output)
  }
}
