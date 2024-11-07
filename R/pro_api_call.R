pro_api_call <- function(
    base_url = "https://api.openalex.org/",
    entity = "works",
    mailto = oa_email(),
    api_key = oa_apikey(),
    verbose = FALSE,
    filter = list(get_filter = "yes", some_more = "happy"),
    search = NULL) {
  # Set base URL -----------------------------------------------------------


  req <- httr2::request(base_url)


  # Add Entitiy to query ---------------------------------------------------


  req <- httr2::req_url_path_append(req, entity)


  # Add Authentication Headers ---------------------------------------------


  if (!is.null(mailto)) {
    req <- httr2::req_url_query(req, mailto = mailto)
  }
  if (!is.null(api_key)) {
    req <- httr2::req_url_query(req, api_key = api_key)
  }


  # Add Filter Headers ----------------------------------------------------


  if (length(filter > 0)) {
    # filter_oa <- paste0(names(filter), ":", paste0("'", filter, "'"), collapse = ",") |>
    filter_oa <- paste0(names(filter), ":", filter, collapse = ",") |>
      URLencode()
    req <- httr2::req_url_query(req, filter = filter_oa)
  }


  # Add Search Headers -----------------------------------------------------



  # Return result ----------------------------------------------------------


  return(req)
}
