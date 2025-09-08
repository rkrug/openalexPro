# Exported functions -----------------------------------------------------

#' Get the OpenAlex API key for requests
#'
#' Retrieves the API key used for OpenAlex requests. The value is taken from
#' the environment variable `openalexR.apikey` if set; otherwise it falls back
#' to the R option `openalexR.apikey`. If neither is defined, `NULL` is
#' returned.
#'
#' This helper mirrors the behavior of `openalexR::oa_apikey()` to make it easy
#' to configure credentials without a hard dependency. Prefer setting the
#' environment variable for non-interactive usage.
#'
#' @return A character scalar with the API key, or `NULL` if not configured.
#'
#' @examples
#' # Set via environment (preferred in non-interactive contexts)
#' Sys.setenv(openalexR.apikey = "<api-key>")
#' oap_apikey()
#'
#' # Or via options
#' options(openalexR.apikey = "<api-key>")
#' oap_apikey()
#'
#' @seealso openalexR::oa_apikey
#' @md
#' @export
oap_apikey <- function() {
  apikey <- Sys.getenv("openalexR.apikey")
  if (apikey == "") {
    apikey <- getOption("openalexR.apikey", default = NULL)
  }
  apikey
}

#' Get the contact email for OpenAlex requests
#'
#' Retrieves the contact email address used in the User-Agent header for
#' OpenAlex requests. The value is taken from the environment variable
#' `openalexR.mailto` if set; otherwise it falls back to the R option
#' `openalexR.mailto`. If neither is defined, `NULL` is returned.
#'
#' This helper mirrors the behavior of `openalexR::oa_email()` to make it easy
#' to configure a contact address without a hard dependency. Supplying a valid
#' email helps with responsible API usage.
#'
#' @return A character scalar with the email address, or `NULL` if not configured.
#'
#' @examples
#' Sys.setenv(openalexR.mailto = "name@example.org")
#' oap_mail()
#'
#' options(openalexR.mailto = "name@example.org")
#' oap_mail()
#'
#' @seealso openalexR::oa_email
#' @md
#' @export
oap_mail <- function() {
  email <- Sys.getenv("openalexR.mailto")
  if (email == "") {
    email <- getOption("openalexR.mailto", default = NULL)
  }
  email
}
