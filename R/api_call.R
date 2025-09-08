#' Perform an API call to the OpenAlex API with retry logic
#'
#' This function performs a request to the OpenAlex API and handles different
#' HTTP status codes with retry for transient errors.
#'
#' @param req A request object created by \code{\link[httr2]{request}}.
#' @param max_tries Maximum number of retry attempts (default: 10)
#' @param error_log File path for error logging (default: "error.log")
#'
#' @return A response object or error.
#'
#' @importFrom httr2 req_perform resp_status
#' @importFrom rlang caller_env
#' @noRd

api_call <- function(
  req,
  max_retries = 10,
  transient_responses = c(500, 502, 503, 504, 429),
  error_log = "error.log"
) {
  # Define a simple file logger --------------------------------------------

  log_fun <- function(
    msg,
    log_file
  ) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    full_msg <- paste0("[", timestamp, "] ", msg, "\n")
    if (!is.null(log_file)) {
      cat(full_msg, file = log_file, append = TRUE)
    } else {
      message(full_msg)
    }
  }

  # Add retry logic for potentially transient errors -----------------------

  req <- req |>
    httr2::req_retry(
      max_tries = max_retries,
      backoff = ~ 2^.x, # exponential backoff
      is_transient = function(resp) {
        status <- httr2::resp_status(resp)
        status %in% transient_responses
      }
    )

  # Perform the request and capture errors ---------------------------------
  resp <- tryCatch(
    {
      httr2::req_perform(req, error_call = rlang::caller_env())
    },
    error = function(e) {
      log_fun(
        paste0(
          "\u274C API call failed after ",
          max_retries,
          " attempts: ",
          e$message
        ),
        error_log
      )
      rlang::abort(message = e$message, class = "api_call_error", parent = e)
    }
  )

  status <- httr2::resp_status(resp)

  # Return immediately if everything is OK ---------------------------------

  if (status == 200) {
    return(resp)
  } else {
    log_fun(
      paste0("\u26A0 Unexpected HTTP status ", status),
      error_log
    )
    rlang::abort(
      paste0("Unexpected HTTP status ", status, "\n  Aborting!"),
      class = "unexpected_http_status"
    )
  }
}
