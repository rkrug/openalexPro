# Internal functions -----------------------------------------------------

get_next_page <- openalexR:::get_next_page

isValidEmail <- openalexR:::isValidEmail

oa_progress <- openalexR:::oa_progress

shorten_oaid <- openalexR:::shorten_oaid

truncated_authors <- openalexR:::truncated_authors


api_request <- function(
  query_url,
  ua,
  query,
  api_key = oa_apikey(),
  json_dir = NULL
) {
  res <- httr::GET(
    query_url,
    ua,
    query = query,
    httr::add_headers(api_key = api_key)
  )

  if (httr::status_code(res) == 400) {
    stop("HTTP status 400 Request Line is too large")
  }

  if (httr::status_code(res) == 429) {
    message("HTTP status 429 Too Many Requests")
    return(list())
  }

  m <- httr::content(res, "text", encoding = "UTF-8")

  if (httr::status_code(res) == 503) {
    mssg <- regmatches(
      m,
      regexpr("(?<=<title>).*?(?=<\\/title>)", m, perl = TRUE)
    )
    message(mssg, ". Please try setting `per_page = 25` in your function call!")
    return(list())
  }

  if (is.null(json_dir)) {
    parsed <- RcppSimdJson::fparse(m) # jsonlite::fromJSON(m, simplifyVector = FALSE)
  } else {
    ## TOD: in this case only parsed$meta$next_cursor is needed - can it be extracted quicker?
    parsed <- list(meta = RcppSimdJson::fparse(m, query = "/meta")) # jsonlite::fromJSON(m, simplifyVector = FALSE)
  }

  if (httr::status_code(res) == 200) {
    if (httr::http_type(res) != "application/json") {
      stop("API did not return json", call. = FALSE)
    }
    if (!is.null(json_dir)) {
      suppressWarnings(
        last_num <- list.files(
          json_dir,
          pattern = "*.json$",
          recursive = FALSE,
          full.names = FALSE
        ) |>
          basename() |>
          gsub(
            pattern = ".json|page_",
            replacement = ""
          ) |>
          as.numeric() |>
          max(
            na.rm = TRUE
          )
      )

      if (is.infinite(last_num)) {
        last_num <- 0
      }
      json_name <- file.path(json_dir, paste0("page_", last_num + 1, ".json"))

      writeLines(
        m,
        json_name
      )
    }
    return(parsed)
  }

  if (httr::http_error(res)) {
    stop(
      sprintf(
        "OpenAlex API request failed [%s]\n%s\n<%s>",
        httr::status_code(res),
        parsed$error,
        parsed$message
      ),
      call. = FALSE
    )
  }

  if (httr::status_code(res) != 429 & httr::status_code(res) != 200) {
    message("HTTP status ", httr::status_code(res))
    return(list())
  }
}


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
#' @param json_dir directory where the JSON files are saved. Default is a temporary directory. If `NULL`,
#'   the return value from call to `openalexR::oa_request()` with all the arguments is returned.
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
pro_request_legacy <- function(
  query_url,
  per_page = 200,
  paging = "cursor",
  pages = NULL,
  count_only = FALSE,
  mailto = oa_email(),
  api_key = oa_apikey(),
  verbose = FALSE,
  json_dir = tempfile(fileext = ".json_dir")
) {
  if (is.null(json_dir)) {
    return(
      openalexR::oa_request(
        query_url = query_url,
        per_page = per_page,
        paging = paging,
        pages = pages,
        count_only = count_only,
        mailto = mailto,
        api_key = api_key,
        verbose = verbose
      )
    )
  }
  #
  #
  #
  warning(
    "The function `pro_request_request` will be deperecated. Use the new `pro_request` function whcih (might?) work differently."
  )

  if (!is.null(json_dir)) {
    if (verbose) {
      message(
        "Deleting and recreating `",
        json_dir,
        "` to avoid inconsistencies."
      )
    }

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
    if (isValidEmail(mailto)) {
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
    next_page <- get_next_page("cursor", i, res)
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
      next_page <- get_next_page("cursor", i, res)
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
    n_items <- min(
      n_items - per_page * (utils::tail(pages, 1) - n_pages),
      per_page * n_pages
    )
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
      "Getting ",
      n_pages,
      pg_plural,
      " of results",
      " with a total of ",
      n_items,
      " records..."
    )
    pb <- oa_progress(n = n_pages, text = "OpenAlex downloading")
  }

  # Activation of cursor pagination
  data <- vector("list", length = n_pages)
  res <- NULL
  for (i in pages) {
    if (verbose) pb$tick()
    Sys.sleep(1 / 10)
    next_page <- get_next_page(paging, i, res)
    query_ls[[paging]] <- next_page
    res <- api_request(query_url, ua, query = query_ls, json_dir = json_dir)
    # if (is.null(json_dir)) {
    #   if (!is.null(res[[result_name]])) data[[i]] <- res[[result_name]]
    # }
  }

  # if (is.null(json_dir)) {
  #   data <- unlist(data, recursive = FALSE)

  #   if (grepl("filter", query_url) && grepl("works", query_url)) {
  #     truncated <- unlist(truncated_authors(data))
  #     if (length(truncated)) {
  #       truncated <- shorten_oaid(truncated)
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


#' Convert JSON files to Apache Parquet files

#'
#' The function takes a directory of JSON files as written from a call to `pro_request(..., json_dir = "FOLDER")`
#' and converts it to a Apache Parquet dataset partitiond by the page.
#'
#' @param json_dir The directory of JSON files returned from `pro_request(..., json_dir = "FOLDER")`.
#' @param corpus parquet dataset; default: temporary directory.
#' @param verbose Logical indicating whether to show a verbose information. Defaults to `TRUE`
#' @param normalize_schemata Determines if the schemata should be normalized, i.e. If not,
#'   certain fields might not work, but for some app;licatons this is faster. Defasults to `FALSE`
#' @param ROW_GROUP_SIZE Only used when `normalize_schemata = TRUE`. Maximum number of rows per row group. Smaller sizes reduce memory
#'   usage, larger sizes improve compression. Defaults to `10000`.
#'   See: \url{https://duckdb.org/docs/sql/statements/copy#row_group_size}
#' @param ROW_GROUPS_PER_FILE Only used when `normalize_schemata = TRUE`. Number of row groups to include in each output Parquet file.
#'   Controls file size and write frequency. Defaults to `1`
#'   See: \url{https://duckdb.org/docs/sql/statements/copy#row_groups_per_file}
#' @param enrich_corpus Determines if the function `enrich_parquets()` should be run. Defatults to `FALSE`
#' @param delete_input Determines if the `json_dir` should be deleted afterwards. Defaults to `FALSE`.
#' @return The function does not returns the directory with the corpus.
#'
#' @details The function uses DuckDB to read the JSON files and to create the
#'   Apache Parquet files. The function creates a DuckDB connection in memory and
#'   readsds the JSON files into DuckDB when needed. Then it creates a SQL query to convert the
#'   JSON files to Apache Parquet files and to copy the result to the specified
#'   directory.
#'
#' @importFrom duckdb duckdb
#' @importFrom DBI dbConnect dbDisconnect dbExecute
#'
#' @md
#'
#' @examples
#' \dontrun{
#' source_to_parquet(json_dir = "json", source_type = "snapshot", corpus = "arrow")
#' }
#' @export

pro_request_json_to_parquet_legacy <- function(
  json_dir = NULL,
  corpus = tempfile(fileext = "_corpus"),
  overwrite = FALSE,
  verbose = TRUE,
  delete_input = FALSE
) {
  ## Check if json_dir is specified
  if (is.null(json_dir)) {
    stop("No json_dir to convert from specified!")
  }

  ## Check if corpus is specified
  if (is.null(corpus)) {
    stop("No corpus to convert to specified!")
  }
  if (file.exists(corpus)) {
    if (!(overwrite)) {
      stop(
        "corpus ",
        corpus,
        " exists.\n",
        "Either specify `overwrite = TRUE` or delete it."
      )
    } else {
      unlink(corpus, recursive = TRUE, force = TRUE)
    }
  }

  ## Read names of json files
  jsons <- list.files(
    json_dir,
    pattern = "*.json$",
    full.names = TRUE
  )

  types <- jsons |>
    basename() |>
    strsplit(split = "_") |>
    sapply(FUN = '[[', 1) |>
    unique()

  if (length(types) > 1) {
    stop("All JSON files must be of the same type!")
  }

  if (types == "group") {
    types <- "group_by"
  }

  ## Create in memory DuckDB
  con <- DBI::dbConnect(duckdb::duckdb())

  on.exit(
    {
      try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
    }
  )

  ## Setup VIEWS

  ### Create `results` view
  paste0(
    "INSTALL json; LOAD json; "
  ) |>
    DBI::dbExecute(conn = con)

  # pb <- txtProgressBar(min = 0, max = length(jsons), style = 3) # style 3 = nice bar

  for (i in seq_along(jsons)) {
    fn <- jsons[i]
    if (verbose) {
      message("Converting ", i, " of ", length(jsons), " : ", fn)
    }

    pn <- basename(fn) |>
      strsplit(split = "_")

    pn <- pn[[1]][length(pn[[1]])] |>
      gsub(pattern = ".json", replacement = "")

    try(
      {
        if (types == "single") {
          paste0(
            "COPY ( ",
            "SELECT ",
            pn,
            " AS page, ",
            "*",
            "FROM read_json_auto('",
            fn,
            "' ) ",
            ") TO '",
            corpus,
            "' ",
            "(FORMAT PARQUET, COMPRESSION SNAPPY, APPEND, PARTITION_BY 'page');"
          ) |>
            DBI::dbExecute(conn = con)
          if (verbose) {
            message("   Done")
          }
        } else {
          paste0(
            "COPY ( ",
            "SELECT ",
            pn,
            " AS page, ",
            "UNNEST(",
            types,
            ", max_depth := 2) ",
            "FROM read_json_auto('",
            fn,
            "' ) ",
            ") TO '",
            corpus,
            "' ",
            "(FORMAT PARQUET, COMPRESSION SNAPPY, APPEND, PARTITION_BY 'page');"
          ) |>
            DBI::dbExecute(conn = con)
          if (verbose) {
            message("   Done")
          }
        }
      },
      silent = !verbose
    )

    # setTxtProgressBar(pb, i)
  }

  if (delete_input) {
    unlink(json_dir, recursive = TRUE, force = TRUE)
  }

  return(normalizePath(corpus))
}
