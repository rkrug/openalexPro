.onAttach <- function(libname, pkgname) {
  # packageStartupMessage("Thank you for using mypackage! 🚀")
  packageStartupMessage(
    "
      This package is in alpha phase and WILL change!

      Use at own risk (as usual)!
    "
  )
}
