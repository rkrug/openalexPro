#' Validate OpenAlex credentials
#'
#' Makes a minimal API request to verify that the api_key is valid.
#'
#' @param api_key API key to validate
#' @param show_credentials shows the api_key using `message()`. USE WITH CAUTION!
#' @return TRUE if credentials work, FALSE otherwise
#' @export
pro_validate_credentials <- function(
  api_key = Sys.getenv("openalexPro.apikey"),
  show_credentials = FALSE
) {
  message("Testing:")
  if (show_credentials) {
    message("    api_key: ", api_key)
  } else {
    message("    api_key: ", strrep("X", nchar(api_key)))
  }
  # Minimal request - just get count of 1 work
  tryCatch(
    {
      count <- pro_count(
        query_url = "https://api.openalex.org/works?per_page=1",
        api_key = api_key
      )
      return(TRUE)
    },
    error = function(e) {
      return(FALSE)
    }
  )
}
