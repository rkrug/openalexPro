library("vcr")

# Platform-agnostic JSON comparison for expect_snapshot_file()
# Parses JSON and compares as R objects, ignoring formatting differences
compare_json <- function(old, new) {
  old_parsed <- jsonlite::read_json(old, simplifyVector = FALSE)
  new_parsed <- jsonlite::read_json(new, simplifyVector = FALSE)
  identical(old_parsed, new_parsed)
}

# Platform-agnostic JSONL comparison for expect_snapshot_file()
# Parses each line as JSON and compares as R objects
compare_jsonl <- function(old, new) {
  parse_jsonl <- function(path) {
    lines <- readLines(path, warn = FALSE)
    lines <- lines[nchar(trimws(lines)) > 0]
    lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)
  }
  identical(parse_jsonl(old), parse_jsonl(new))
}

# Factory function to create a JSON comparator that ignores specified fields
# Usage: compare = compare_json_ignore(c("db_response_time_ms", "updated_date"))
compare_json_ignore <- function(ignore_fields) {
  remove_fields <- function(obj, fields) {
    if (is.null(obj) || length(fields) == 0) return(obj)
    if (is.list(obj)) {
      obj <- obj[!names(obj) %in% fields]
      obj <- lapply(obj, remove_fields, fields = fields)
    }
    obj
  }
  function(old, new) {
    old_parsed <- jsonlite::read_json(old, simplifyVector = FALSE)
    new_parsed <- jsonlite::read_json(new, simplifyVector = FALSE)
    old_clean <- remove_fields(old_parsed, ignore_fields)
    new_clean <- remove_fields(new_parsed, ignore_fields)
    identical(old_clean, new_clean)
  }
}

vcr_dir <- vcr::vcr_test_path("fixtures", "vcr")
vcr::vcr_configure_log(file = file.path(vcr_dir, "vcr.log"))

invisible(vcr::vcr_configure(
  dir = vcr_dir,
  # Filter the request header where the token is sent, make sure you know
  # how authentication works in your case and read the Security chapter :-)
  # filter_request_headers = list(Authorization = "My bearer token is safe")
  record = "new_episodes",
  filter_request_headers = list(api_key = "<api-key>"),
  filter_query_parameters = list(api_key = "<api-key>")
))

# try(
#   {
#     Sys.setenv(openalexPro.apikey = keyring::key_get("API_openalex"))
#     Sys.setenv(openalexPro.email = "Rainer@krugs.de")
#   }
# )

# if (!openalexPro::pro_validate_credentials()) {
#   stop("invalid credentials!")
# }
