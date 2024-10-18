# Exported functions -----------------------------------------------------

#' Get OpenAlex API key
#'
#' Re-export from openalexR::oa_apikey()
#' @export
#' @importFrom openalexR oa_apikey
oa_apikey <- openalexR::oa_apikey

#' Get OpenAlex email address
#'
#' Re-export from openalexR::oa_email()
#' @export
#' @importFrom openalexR oa_email
oa_email <- openalexR::oa_email

#' Costruct OpenAlex query
#'
#' Re-export from openalexR::oa_query()
#' @export
#' @importFrom openalexR oa_query
oa_query <- openalexR::oa_query


# Internal functions -----------------------------------------------------


get_next_page <- openalexR:::get_next_page

isValidEmail <- openalexR:::isValidEmail

oa_progress <- openalexR:::oa_progress

shorten_oaid <- openalexR:::shorten_oaid

truncated_authors <- openalexR:::truncated_authors
