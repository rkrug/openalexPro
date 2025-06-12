library("vcr")

vcr_dir <- vcr::vcr_test_path("fixtures", "vcr")
vcr::vcr_configure_log(file = file.path(vcr_dir, "vcr.log"))

invisible(vcr::vcr_configure(
  dir = vcr_dir,
  # Filter the request header where the token is sent, make sure you know
  # how authentication works in your case and read the Security chapter :-)
  # filter_request_headers = list(Authorization = "My bearer token is safe")
  filter_request_headers = list(api_key = "<api-key>"),
  filter_query_parameters = list(api_key = "<api-key>")
))

if (is.null(oa_apikey())) {
  options(openalexR.apikey = "<api-key>")
}
if (is.null(oa_email())) {
  options(openalexR.mailto = "rainer@krugs.de")
}
