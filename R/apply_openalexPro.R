#' Apply changes to the package `openalexR`
#'
#' This packagew introduces several changes to the package `openalexR`. These can
#' be applied by specifying the name of the fix. These are at the moment:
#' - oa_request: adds option to `oa_fetch` to save json files (one per page)
#'   from the call to the OpenAlex API. Changes in the function api_request()
#'   and oa_request() are done.
#'
#' @param which Which function to fix. Can be "oa_request", "api_request", or
#'   both.
#' @md
#' @rdname apply_openalexPro
#'
#' @importFrom utils assignInNamespace
#' @export

apply_openalexPro <- function() {
  utils::assignInNamespace("api_request", api_request, ns = "openalexR")
  utils::assignInNamespace("oa_request", oa_request, ns = "openalexR") # works
}


#' Revert **all** changes to the package `openalexR` done by `apply_openalexPro()`
#'
#' This function undoes the changes introduced by \code{\link{apply_openalexPro}}.
#' It unloads the namespace and reloads the package.
#'
#' @examples
#' \dontrun{
#' apply_openalexPro()
#' unapply_openalexPro()
#' }
#' @rdname apply_openalexPro
#' @export
#'
unapply_openalexPro <- function() {
  unloadNamespace("openalexR")
  library(openalexR)
}
