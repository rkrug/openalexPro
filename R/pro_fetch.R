#' Fetch and convert OpenAlex data
#'
#' Convenience wrapper around \code{\link{pro_request}},
#' \code{\link{pro_request_jsonl}} and
#' \code{\link{pro_request_jsonl_parquet}}.
#'
#' The function
#' \itemize{
#'   \item downloads records from OpenAlex via \code{pro_request()} into a
#'     \code{"json"} subfolder of \code{output},
#'   \item converts the JSON files to \code{jsonl} via
#'     \code{pro_request_jsonl()} into a \code{"jsonl"} subfolder, and
#'   \item converts the jsonl files to an Apache Parquet dataset via
#'     \code{pro_request_jsonl_parquet()} into a \code{"parquet"} subfolder.
#' }
#'
#' This is a high-level helper for the common workflow of going from an
#' OpenAlex query URL to a local Parquet dataset in a single call.
#' In most cases, this function should be sufficient, but if more control is needed,
#' the individual functions have to be called separately.
#'
#' **This function assumes `count_only == FALSE`**
#'
#' @inheritParams pro_request
#' @param count_only Do not use it here. The function will abort if it set to
#' `TRUE` and give a warning if `FALSE`
#'
#' @param output Directory where all intermediate (\code{json},
#'   \code{jsonl}) and final (\code{parquet}) results are stored.
#'   If it does not exist, it is created. If \code{NULL}, a temporary
#'   directory is created.
#'
#' @return Invisibly, the normalized path of the \code{parquet} subfolder
#'   inside \code{output}, i.e. the value returned by
#'   \code{pro_request_jsonl_parquet()}.
#'
#' @md
#'
#' @export
pro_fetch <- function(
  query_url,
  pages = 1000,
  output = NULL,
  overwrite = FALSE,
  mailto = oap_mail(),
  api_key = oap_apikey,
  workers = 1,
  verbose = FALSE,
  progress = TRUE,
  count_only,
  error_log = NULL
) {
  if (!missing(count_only)) {
    warning("`count_only` is set but will be assumed to be `FALSE`")
    if (count_only) {
      stop("Setting `count_only = TRUE` is not supported in `pro_fetch()`")
    }
  }
  if (is.null(output)) {
    output <- tempdir()
  }

  if (!dir.exists(output)) {
    dir.create(
      output,
      recursive = TRUE,
      showWarnings = FALSE
    )
  }

  pro_request(
    query_url = query_url,
    pages = pages,
    output = file.path(output, "json"),
    overwrite = overwrite,
    mailto = mailto,
    api_key = api_key,
    workers = workers,
    verbose = verbose,
    progress = progress,
    count_only = FALSE,
    error_log = error_log
  ) |>
    pro_request_jsonl(
      output = file.path(output, "jsonl"),
      overwrite = overwrite,
      delete_input = FALSE
    ) |>
    pro_request_jsonl_parquet(
      output = file.path(output, "parquet"),
      overwrite = overwrite,
      verbose = verbose,
      delete_input = FALSE
    )
}
