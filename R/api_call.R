#' Perform an API call to the OpenAlex API with retry logic
#'
#' This function performs a request to the OpenAlex API and handles different
#' HTTP status codes with retry for transient errors.
#'
#' @param req A request object created by \code{\link[httr2]{request}}.
#' @param max_tries Maximum number of retry attempts (default: 5)
#' @return A response object or error.
#' @importFrom httr2 req_perform resp_status
#' @importFrom rlang caller_env
#' @noRd

api_call <- function(
  req,
  max_retries = 5
) {
  # Add  retry logic for potentially transient errors ---
  req <- req |>
    httr2::req_retry(
      max_tries = 5,
      backoff = ~ 2^.x, # exponential backoff
      is_transient = function(resp) {
        status <- httr2::resp_status(resp)
        status %in% c(500, 502, 503, 504, 429)
      }
    )

  # Perform the request and capture errors
  resp <- httr2::req_perform(
    req,
    error_call = rlang::caller_env()
  )

  status <- httr2::resp_status(resp)

  # Return immediately if everything is OK
  if (status == 200) {
    return(resp)
  }

  # # Further processing
  # content_type <- httr2::resp_content_type(resp)

  # # Parse body as string for inspection
  # resp_string <- httr2::resp_body_string(resp)

  # # Special cases handling
  # if (status == 400) {
  #   stop("HTTP status 400 Request Line is too large")
  # }

  # if (status == 429) {
  #   stop("HTTP status 429 Too Many Requests")
  #   # return(empty_res)
  # }

  # if (status == 503) {
  #   mssg <- regmatches(
  #     resp_string,
  #     regexpr("(?<=<title>).*?(?=<\\/title>)", resp_string, perl = TRUE)
  #   )
  #   stop(mssg, ". Please try setting `per_page = 25` in your function call!")
  #   # return(empty_res)
  # }

  # # Generic error handling
  # if (status >= 400) {
  #   parsed <- tryCatch(
  #     jsonlite::fromJSON(resp_string, simplifyVector = FALSE),
  #     error = function(e) list(error = "Unknown error", message = resp_string)
  #   )
  #   stop(
  #     sprintf(
  #       "OpenAlex API request failed [%s]\n%s\n<%s>",
  #       status,
  #       parsed$error,
  #       parsed$message
  #     ),
  #     call. = FALSE
  #   )
  # }

  # Any other unexpected status (not 429 or 200)
  stop("HTTP status ", status)
}
