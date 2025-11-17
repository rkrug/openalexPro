library("vcr")

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

if (is.null(oap_apikey())) {
  options(openalexR.apikey = "<api-key>")
}
if (is.null(oap_mail())) {
  options(openalexR.mailto = "rainer@krugs.de")
}

api <- NULL
try(
  api <- keyring::key_get("API_openalex"),
  silent = TRUE
)
if (is.null(api)) {
  try(
    Sys.unsetenv(openalexR.apikey),
    silent = TRUE
  )
} else {
  Sys.setenv(openalexR.apikey = api)
}
