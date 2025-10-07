# helpers -----------------------------------------------------------------

#' @keywords internal
#' @noRd
.oa_collapse <- function(x) {
  if (is.null(x)) {
    return(character(0))
  }
  x <- x[!is.na(x)]
  if (!length(x)) {
    return(character(0))
  }
  if (is.logical(x)) {
    x <- tolower(as.character(x))
  }
  if (length(x) == 1) as.character(x) else paste(x, collapse = "|")
}

#' @keywords internal
#' @noRd
.oa_build_filter <- function(fl) {
  if (is.null(fl) || !length(fl)) {
    return(NULL)
  }
  # drop empty/all-NA entries
  fl <- Filter(function(v) !(length(v) == 0 || all(is.na(v))), fl)
  if (!length(fl)) {
    return(NULL)
  }

  parts <- unlist(
    Map(
      function(k, v) {
        vv <- .oa_collapse(v)
        if (!length(vv)) {
          return(character(0))
        }
        paste0(k, ":", vv)
      },
      names(fl),
      fl
    ),
    use.names = FALSE
  )

  if (length(parts)) paste(parts, collapse = ",") else NULL
}

#' @keywords internal
#' @noRd
.oa_build_select <- function(select) {
  if (is.null(select) || !length(select)) {
    return(NULL)
  }
  paste(select, collapse = ",")
}

#' @keywords internal
#' @noRd
`%||%` <- function(a, b) if (is.null(a)) b else a

# validation --------------------------------------------------------------

#' @keywords internal
#' @noRd
.fuzzy_suggest <- function(bad, allowed, max_dist = 3L) {
  if (is.null(allowed) || !length(allowed) || !length(bad)) {
    return(rep(NA_character_, length(bad)))
  }
  vapply(
    bad,
    function(x) {
      d <- utils::adist(x, allowed)
      m <- which.min(d)
      if (length(m) && is.finite(d[m]) && d[m] <= max_dist) {
        allowed[m]
      } else {
        NA_character_
      }
    },
    character(1L)
  )
}

#' @keywords internal
#' @noRd
.validate_select <- function(select) {
  allowed <- opt_select_fields()
  if (
    is.null(allowed) || !length(allowed) || is.null(select) || !length(select)
  ) {
    return(invisible(TRUE))
  }
  bad <- setdiff(select, allowed)
  if (!length(bad)) {
    return(invisible(TRUE))
  }

  sug <- .fuzzy_suggest(bad, allowed)
  have <- !is.na(sug)
  msg <- paste0(
    "Invalid select field(s): ",
    paste(bad, collapse = ", "),
    ".",
    if (any(have)) {
      paste0(
        "\nDid you mean: ",
        paste(paste0(bad[have], " \u2192 ", sug[have]), collapse = ", "),
        "?"
      )
    } else {
      ""
    },
    "\nValid select fields are defined in `opt_select_fields()`."
  )
  stop(msg, call. = FALSE)
}

#' @keywords internal
#' @noRd
.validate_filter <- function(fl) {
  if (is.null(fl) || !length(fl)) {
    return(invisible(TRUE))
  }
  allowed <- opt_filter_names()
  if (is.null(allowed) || !length(allowed)) {
    return(invisible(TRUE))
  }

  bad <- setdiff(names(fl), allowed)
  if (!length(bad)) {
    return(invisible(TRUE))
  }

  sug <- .fuzzy_suggest(bad, allowed)
  have <- !is.na(sug)
  msg <- paste0(
    "Invalid filter name(s): ",
    paste(bad, collapse = ", "),
    ".",
    if (any(have)) {
      paste0(
        "\nDid you mean: ",
        paste(paste0(bad[have], " \u2192 ", sug[have]), collapse = ", "),
        "?"
      )
    } else {
      ""
    },
    "\nValid filter names are defined in `opt_filter_names()`."
  )
  stop(msg, call. = FALSE)
}

# main builder ------------------------------------------------------------

#' Build an OpenAlex request (httr2)
#'
#' Construct an \code{httr2} request for the OpenAlex API. All filters must be
#' supplied as named \code{...} arguments (e.g., \code{from_publication_date = "2020-01-01"}).
#'
#' Filter names are validated via \code{.validate_filter()} using
#' \code{opt_filter_names()}. \code{select} fields are validated via
#' \code{.validate_select()} using \code{`opt_select_fields()`}.
#'
#' @param entity Character; one of \code{"works"}, \code{"authors"}, \code{"venues"},
#'   \code{"institutions"}, \code{"concepts"}, \code{"publishers"}, \code{"funders"}.
#' @param id Optional single ID (e.g., \code{"W1775749144"}) to fetch one entity.
#' @param multiple_id Logical; if \code{TRUE} and \code{id} is a vector, the IDs are
#'   moved into the \code{ids.openalex} filter and \code{id} is cleared.
#' @param search Optional full-text search string.
#' @param group_by Optional field to group by (facets), e.g. \code{"type"}.
#' @param select Optional character vector of fields to return.
#' @param options Optional named list of additional query parameters (e.g.,
#'   \code{list(per_page = 200, sort = "cited_by_count:desc", cursor = "*", sample = 100)}).
#' @param endpoint Base API URL. Defaults to \code{"https://api.openalex.org"}.
#' @param mailto Optional email to join the polite pool; added as a query parameter and
#'   appended to the \code{User-Agent}.
#' @param user_agent Optional custom \code{User-Agent}.
#' @param ... Filters as named arguments. Values may be scalars or vectors (vectors
#'   are collapsed with \code{"|"} to express OR).
#'
#' @return An individual URL or a list of URLs.
#'
#' @examples
#' \dontrun{
#'
#' req <- oa_build_req(
#'   entity = "works",
#'   search = "biodiversity",
#'   from_publication_date = "2020-01-01",
#'   language = c("en","de"),
#'   select = c("id","title","publication_year"),
#'   options = list(per_page = 5),
#'   mailto = "you@example.org"
#' )
#' # resp <- api_call(req)
#' # httr2::resp_body_json(resp)
#' }
#'
#' @export
#' @importFrom httr2 request req_url_path_append req_url_query req_headers
#' @importFrom utils adist
pro_query <- function(
  entity = c(
    "works",
    "authors",
    "venues",
    "institutions",
    "concepts",
    "publishers",
    "funders"
  ),
  id = NULL,
  multiple_id = FALSE,
  search = NULL,
  group_by = NULL,
  select = NULL,
  options = NULL,
  endpoint = "https://api.openalex.org",
  mailto = NULL,
  user_agent = NULL,
  ...
) {
  entities <- c(
    "works",
    "authors",
    "venues",
    "institutions",
    "concepts",
    "publishers",
    "funders"
  )
  entity <- match.arg(tolower(entity), entities)

  # gather filters via ...
  filter <- list(...)

  # move vector IDs into filter if requested
  if (!is.null(id) && multiple_id) {
    filter <- c(filter, list(`ids.openalex` = unique(id)))
    id <- NULL
  }

  # validate filters and select fields
  .validate_filter(filter)
  .validate_select(select)

  # prepare chunking ------------------------------------------------------

  chunk_targets <- c(
    "openalex",
    "ids.openalex",
    "doi",
    "cites",
    "cited_by"
  )
  chunk_limit <- 50L

  filter_batches <- list(filter)
  if (length(filter)) {
    filter_batches <- list(filter)
    for (key in intersect(names(filter), chunk_targets)) {
      next_batches <- list()
      for (current in filter_batches) {
        values <- current[[key]]
        values <- values[!is.na(values)]
        if (length(values) > chunk_limit) {
          splits <- split(
            values,
            ceiling(seq_along(values) / chunk_limit)
          )
          next_batches <- c(
            next_batches,
            lapply(splits, function(chunk) {
              current[[key]] <- chunk
              current
            })
          )
        } else {
          next_batches <- c(next_batches, list(current))
        }
      }
      filter_batches <- next_batches
    }
  }

  if (!length(filter_batches)) {
    filter_batches <- list(filter)
  }

  # build strings
  select_str <- .oa_build_select(select)

  # base request + path
  req_base <- httr2::request(endpoint)
  path <- if (is.null(id)) entity else paste(entity, id, sep = "/")
  req_base <- httr2::req_url_path_append(req_base, path)

  # assemble query components shared across batches (drop NULLs later)
  shared_q <- list(
    search = search,
    group_by = group_by,
    select = select_str
  )
  if (length(options)) {
    shared_q <- c(shared_q, options)
  }

  urls <- vapply(
    filter_batches,
    function(batch_filter) {
      filter_str <- .oa_build_filter(batch_filter)
      q <- c(list(filter = filter_str), shared_q)
      q <- Filter(Negate(is.null), q)
      req <- req_base
      if (length(q)) {
        req <- httr2::req_url_query(req, !!!q)
      }
      req$url
    },
    character(1)
  )

  if (length(urls) > 1) {
    urls <- as.list(urls)
    names(urls) <- paste0("chunk_", seq_along(urls))
  }

  return(urls)
}
