#' Execute a jq transformation from an OpenAlex-style JSON to JSONL
#'
#' This function runs a jq filter to extract records from the "results" array
#' (or from the root if type = "single"), reconstruct the abstract text,
#' generate a citation string, and optionally add a page field. It writes the
#' result as newline-delimited JSON (.jsonl), suitable for Arrow or DuckDB. For
#' details on the jq filter logic, see the \code{\link{vignette}}("jq", package
#' = "openalexPro2").
#'
#' @param input_json Path to the input JSON file
#' @param output_jsonl Path to the output .jsonl file
#' @param add_columns List of additional fields to be added to the output. They
#'   nave to be provided as a named list, e./g. `list(column_1 = "value_1",
#'   column_2 = 2)`. Only Scalar values are supported.
#' @param jq_filter Optional custom jq filter string. If NULL, the default
#'   filter is used.
#' @param page Optional integer to be added as a "page" field in each output
#'   record
#' @param type Either "results" (default, expects a .results[] array) or
#'   "single" (treat input as array of records directly)
#'
#' @return Invisibly returns the output path
#'
#' @importFrom jqr jq
#'
#' @export
jq_execute <- function(
  input_json,
  output_jsonl,
  add_columns = list(),
  jq_filter = NULL,
  page = NULL,
  type = c("results", "single", "group_by")
) {
  type <- match.arg(type)

  if (is.null(jq_filter)) {
    root <- switch(
      type,
      "results" = ".results[] | ",
      "group_by" = ".group_by[] | ",
      "single" = "",
      stop("Not supported type!")
    )

    jq_filter <- paste0(
      root,
      '
        (
          if .abstract_inverted_index == null then
            .
          else
            . + {
              abstract: (
                [
                  .abstract_inverted_index
                  | to_entries
                  | map(.value[] as $i | {pos: $i, word: .key})
                  | .[]
                ]
                | sort_by(.pos)
                | map(.word)
                | join(" ")
              )
            }
          end
        )
      | . + {
          citation:
            (if (.authorships | length) == 1 then
               .authorships[0].author.display_name + " (" + (.publication_year|tostring) + ")" 
             elif (.authorships | length) == 2 then
               .authorships[0].author.display_name + " & " + .authorships[1].author.display_name + " (" + (.publication_year|tostring) + ")"
             elif (.authorships | length) > 2 then
               .authorships[0].author.display_name + " et al. (" + (.publication_year|tostring) + ")"
             else null end)
        ',
      # Insert comma-separated additional fields at top level, not inside
      # citation!
      if (length(add_columns)) {
        paste0(
          ", ",
          paste(
            sprintf('%s: "%s"', names(add_columns), add_columns),
            collapse = ", "
          )
        )
      } else {
        ""
      },
      '
      }
      | del(.abstract_inverted_index)
      '
    )
  }

  if (!is.null(page)) {
    jq_filter <- paste0(jq_filter, " | . + {page: ", page, "}")
  }

  jqr::jq(
    file(input_json),
    jq_filter,
    out = output_jsonl
  )

  invisible(output_jsonl)
}
