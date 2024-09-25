api_request <- function(
    query_url,
    ua,
    query,
    api_key = oa_apikey(),
    json_dir = NULL) {
  if (!is.null(json_dir)) {
    if (!dir.exists(json_dir)) {
      dir.create(json_dir, recursive = TRUE)
    }
  }
  res <- httr::GET(query_url, ua, query = query, httr::add_headers(api_key = api_key))

  if (httr::status_code(res) == 400) {
    stop("HTTP status 400 Request Line is too large")
  }

  if (httr::status_code(res) == 429) {
    message("HTTP status 429 Too Many Requests")
    return(list())
  }

  m <- httr::content(res, "text", encoding = "UTF-8")

  if (httr::status_code(res) == 503) {
    mssg <- regmatches(m, regexpr("(?<=<title>).*?(?=<\\/title>)", m, perl = TRUE))
    message(mssg, ". Please try setting `per_page = 25` in your function call!")
    return(list())
  }

  if (is.null(json_dir)) {
    parsed <- jsonlite::fromJSON(m, simplifyVector = FALSE)
  } else {
    ## TOD: in this case only parsed$meta$next_cursor is needed - can it be extracted quicker?
    parsed <- jsonlite::fromJSON(m, simplifyVector = FALSE)
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
            pattern = ".json|result_",
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
      json_name <- file.path(json_dir, paste0("result_", last_num + 1, ".json"))

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
