#' Check whether jq is installed
#'
#' This function checks if the jq binary is available on the system path or at the specified location.
#' If not, it throws an error with platform-specific installation guidance.
#'
#' @param jq_path Path to the jq executable (default: "jq")
#' @return NULL (invisibly)
#' @keywords internal
jq_check <- function(jq_path = "jq") {
  if (Sys.which(jq_path) == "") {
    os <- Sys.info()[["sysname"]]
    msg <- switch(
      os,
      "Linux" = "Install jq using `sudo apt install jq`.",
      "Darwin" = "Install jq using Homebrew (`brew install jq`) or download a binary from https://stedolan.github.io/jq/download/.",
      "Windows" = "Install jq from https://stedolan.github.io/jq/download/ and add it to your PATH.",
      "Unknown OS. Please install jq manually."
    )
    stop("jq is not installed or not on the PATH. ", msg, call. = FALSE)
  }
  return(TRUE)
}
