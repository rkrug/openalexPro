#' Get available filter names from OpenAlex API
#'
#' @param update logical. If `TRUE` update the existing value. Default is `FALSE`.
#' @return A character vector of available filter names
#'
#' @importFrom httr2 request req_url_query resp_body_json
#' @export
opt_filter_names <- function(update = FALSE) {
  if (update) {
    oao <- getOption("openalexPro")
    oao$filter_names <- NULL
    options(openalexPro = oao)
  }

  if (is.null(getOption("openalexPro")$filter_names)) {
    api_key <- pro_api_key()
    req <- httr2::request("https://api.openalex.org/works") |>
      httr2::req_url_query(filter = "DOESNTEXIST:1")
    if (!is.null(api_key) && nzchar(api_key)) {
      req <- req |> httr2::req_url_query(api_key = api_key)
    }
    resp <- req |>
      api_call(get_html_response = NULL) |>
      httr2::resp_body_json()

    filter <- resp$message |>
      strsplit(split = ", ")

    filter <- filter[[1]][-1]

    oao <- getOption("openalexPro")
    if (is.null(oao)) {
      oao <- list(
        filter_names = filter
      )
    } else {
      oao$filter_names <- filter
    }
    options(openalexPro = oao)
  }
  return(getOption("openalexPro")$filter_names)
}
