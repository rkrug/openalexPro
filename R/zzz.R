.onAttach <- function(libname, pkgname) {
  # packageStartupMessage("Thank you for using mypackage! 🚀")
  packageStartupMessage(
    "
      This package is in beta phase.

      The functions definitions are likely stable in the 
      release on r-universe https://rkrug.r-universe.dev/openalexPro,
      but nothing can be assumed in the dev version on GittHub!

      As usual, the author(s) do not take any responsibility for the 
      correct functioning of the package or any responsibility for 
      resulting wrong statements , delays, costs, etc.
    "
  )
}
