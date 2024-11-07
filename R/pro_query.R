pro_query <- function(
    filter = NULL,
    multiple_id = FALSE,
    identifier = NULL,
    entity = if (is.null(identifier)) NULL else id_type(identifier[[1]]),
    options = NULL,
    search = NULL,
    group_by = NULL,
    endpoint = "https://api.openalex.org",
    verbose = FALSE,
    ...) {
  entity <- match.arg(entity, oa_entities())
  filter <- c(filter, list(...))

  empty_filters <- which(lengths(filter) == 0)
  if (length(empty_filters) > 0) {
    filter <- filter[-empty_filters]
    stop(
      "Filters must have a value: ",
      paste(names(empty_filters), collapse = ", "),
      call. = FALSE
    )
  }

  if (length(filter) > 0 || multiple_id) {
    null_locations <- vapply(filter, is.null, logical(1))
    filter[null_locations] <- NULL # remove NULL elements
    filter <- lapply(filter, asl)
    flt_ready <- mapply(append_flt, filter, names(filter))
    flt_ready <- paste0(flt_ready, collapse = ",")
  } else {
    flt_ready <- list()
  }

  if (!is.null(options$select)) {
    options$select <- paste(options$select, collapse = ",")
  }

  if (is.null(identifier) || multiple_id) {
    if (length(filter) == 0 &&
      is.null(search) &&
      is.null(group_by) &&
      is.null(options$sample)) {
      message("Identifier is missing, please specify filter or search argument.")
      return()
    }

    path <- entity
    query <- c(
      list(
        filter = flt_ready,
        search = search,
        group_by = group_by
      ),
      options
    )
  } else {
    path <- paste(entity, identifier, sep = "/")
    query <- options
  }

  # query_url <- httr::modify_url(
  #   endpoint,
  #   path = path,
  #   query = query
  # )

  query_url <- httr2::url_parse(endpoint)
  query_url$query <- query
  url_build(query_url)

  if (is.null(oa_print())) {
    url_display <- query_url
  } else {
    query_url <- utils::URLdecode(query_url)
    query_url_more <- if (oa_print() < nchar(query_url)) "..."
    url_display <- paste0(substr(query_url, 1, oa_print()), query_url_more)
  }

  if (verbose) message("Requesting url: ", url_display)

  query_url
}
