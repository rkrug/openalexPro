#' Load a SQL file
#'
#' Load a SQL file, remove all comments starting with "--" and return the SQL as
#' a single string.
#'
#' @param sql_file The path to the SQL file.
#'
#' @return A string containing the SQL code which c an be executed in e.g. `DBI::dbExecute(conn, sql)`
#'
#' @export
load_sql_file <- function(sql_file = NULL) {
  if (is.null(sql_file)) {
    stop("`sql_file` needs to be specified!")
  }
  sql <- sql_file |>
    base::readLines(warn = FALSE) |>
    gsub(pattern = "--.*$", replacement = "") |>
    paste0(collapse = "\n")
  ##
  return(sql)
}
