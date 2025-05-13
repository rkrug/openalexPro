.onLoad <- function(libname, pkgname) {
  # packageStartupMessage("Thank you for using mypackage! 🚀")
  packageStartupMessage(
    "
      In this version the function `pro_request()` has been renamed rewritten!
      It SHOULD behave identical, except for some changed arguments.

      Consider using changing ypur code to use the new version instead.

      If this is not feasible, the old function is available as `pro_request_legacy()`.
      
      Please note that this function will not receive any updates and might (will?) break in the future!
    "
  )
}
