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

# try(
#   {
#     Sys.setenv(openalexPro.apikey = keyring::key_get("API_openalex"))
#     Sys.setenv(openalexPro.email = "Rainer@krugs.de")
#   }
# )

# if (!openalexPro::pro_validate_credentials()) {
#   stop("invalid credentials!")
# }
