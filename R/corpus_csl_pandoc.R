#' Convert a corpus to CSL JSON (chunked)
#'
#' Maps an OpenAlex corpus (Arrow Dataset/Table or data.frame/tibble) to CSL
#' JSON items and writes them into chunked files. The function creates the
#' directory `output` (if not present) and writes files `chunk_1.json`,
#' `chunk_2.json`, ... inside that directory.
#'
#' @param corpus Path to parquet dataset, parquet Dataset/Table (e.g., from `arrow::open_dataset()`) or
#'   a data.frame/tibble (e.g., from `dplyr::collect()`).
#' @param output Path to a directory to create and populate with chunked CSL
#'   JSON files (`chunk_1.json`, `chunk_2.json`, ...).
#' @param chunk_size Rows processed per chunk via DuckDB. Default: 10000.
#' @param overwrite Overwrite `output` if it exists. Default: FALSE.
#' @param verbose Print progress messages. Default: TRUE.
#'
#' @return Invisibly returns `normalizePath(output)`.
#'
#' @md
#'
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery
#' @importFrom duckdb duckdb duckdb_register_arrow
#'
#' @export
corpus_to_csljson <- function(
  corpus,
  output,
  chunk_size = 10000,
  overwrite = FALSE,
  verbose = TRUE
) {
  if (missing(corpus) || is.null(corpus)) {
    stop("`corpus` must be provided.")
  }
  if (is.character(corpus)) {
    corpus <- arrow::open_dataset(corpus)
  }

  if (missing(output) || is.null(output)) {
    stop("`output` must be provided.")
  }
  if (file.exists(output)) {
    if (!overwrite) {
      stop("`output` exists. Set `overwrite = TRUE`.")
    }
    unlink(output, recursive = TRUE, force = TRUE)
  }
  dir.create(output, recursive = TRUE, showWarnings = FALSE)

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(
    try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE),
    add = TRUE
  )

  arrow_obj <- if (inherits(corpus, "data.frame")) {
    arrow::as_arrow_table(corpus)
  } else {
    corpus
  }
  tryCatch(
    {
      duckdb::duckdb_register_arrow(con, "src", arrow_obj)
    },
    error = function(e) {
      duckdb::duckdb_register_arrow(con, "src", arrow::as_arrow_table(corpus))
    }
  )

  n_total <- tryCatch(
    {
      as.integer(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM src")$n[1])
    },
    error = function(e) NA_integer_
  )
  if (is.na(n_total) || n_total < 0) {
    stop("Could not determine number of records in corpus.")
  }

  # Prepare chunked output directory (already created above)

  # Dynamically build a robust SELECT mapping to common OpenAlex fields
  cols <- colnames(DBI::dbGetQuery(con, "SELECT * FROM src LIMIT 0"))
  has <- function(n) n %in% cols
  title_expr <- if (has("display_name")) {
    "display_name"
  } else if (has("title")) {
    "title"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  year_expr <- if (has("publication_year")) {
    "publication_year"
  } else {
    "CAST(NULL AS INTEGER)"
  }
  doi_expr <- if (has("doi")) "doi" else "CAST(NULL AS VARCHAR)"
  type_expr <- if (has("type")) "type" else "CAST(NULL AS VARCHAR)"
  venue_expr <- if (has("host_venue") && has("primary_location")) {
    "COALESCE(host_venue.display_name, primary_location.source.display_name)"
  } else if (has("host_venue")) {
    "host_venue.display_name"
  } else if (has("primary_location")) {
    "primary_location.source.display_name"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  venue_type_expr <- if (has("host_venue") && has("primary_location")) {
    "COALESCE(host_venue.type, primary_location.source.type)"
  } else if (has("host_venue")) {
    "host_venue.type"
  } else if (has("primary_location")) {
    "primary_location.source.type"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  # Additional venue metadata
  publisher_expr <- if (has("host_venue")) {
    "host_venue.publisher"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  issn_l_expr <- if (has("host_venue")) {
    "host_venue.issn_l"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  issns_expr <- if (has("host_venue")) "host_venue.issn" else "[]"
  volume_expr <- if (has("biblio")) "biblio.volume" else "CAST(NULL AS VARCHAR)"
  issue_expr <- if (has("biblio")) "biblio.issue" else "CAST(NULL AS VARCHAR)"
  fpage_expr <- if (has("biblio")) {
    "biblio.first_page"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  lpage_expr <- if (has("biblio")) {
    "biblio.last_page"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  url_expr <- {
    options <- c(
      if (has("doi_url")) "doi_url" else NULL,
      if (has("open_access")) "open_access.oa_url" else NULL,
      if (has("primary_location")) {
        "primary_location.landing_page_url"
      } else {
        NULL
      },
      if (has("id")) "id" else NULL
    )
    if (length(options) == 0) {
      "CAST(NULL AS VARCHAR)"
    } else {
      paste0("COALESCE(", paste(options, collapse = ", "), ")")
    }
  }
  abstract_expr <- if (has("abstract")) {
    "try_cast(abstract AS VARCHAR)"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  language_expr <- if (has("language")) "language" else "CAST(NULL AS VARCHAR)"
  pubdate_expr <- if (has("publication_date")) {
    "publication_date"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  authors_expr <- if (has("authorships")) {
    "list_transform(authorships, x -> COALESCE(x.author.display_name, x.raw_author_name))"
  } else {
    "[]"
  }
  orcids_expr <- if (has("authorships")) {
    "list_transform(authorships, x -> x.author.orcid)"
  } else {
    "[]"
  }
  keywords_expr <- if (has("concepts")) {
    "list_transform(concepts, x -> x.display_name)"
  } else {
    "[]"
  }
  oa_is_expr <- if (has("open_access")) {
    "open_access.is_oa"
  } else {
    "CAST(NULL AS BOOLEAN)"
  }
  oa_status_expr <- if (has("open_access")) {
    "open_access.oa_status"
  } else {
    "CAST(NULL AS VARCHAR)"
  }
  cited_by_expr <- if (has("cited_by_count")) {
    "cited_by_count"
  } else {
    "CAST(NULL AS INTEGER)"
  }
  select_sql <- paste0(
    "SELECT\n",
    "  ",
    if (has("id")) "id" else "CAST(NULL AS VARCHAR) AS id",
    ",\n",
    "  ",
    title_expr,
    " AS title,\n",
    "  ",
    year_expr,
    " AS year,\n",
    "  ",
    doi_expr,
    " AS doi,\n",
    "  ",
    type_expr,
    " AS type,\n",
    "  ",
    venue_expr,
    " AS venue,\n",
    "  ",
    venue_type_expr,
    " AS venue_type,\n",
    "  ",
    volume_expr,
    " AS volume,\n",
    "  ",
    issue_expr,
    " AS number,\n",
    "  ",
    fpage_expr,
    " AS first_page,\n",
    "  ",
    lpage_expr,
    " AS last_page,\n",
    "  ",
    url_expr,
    " AS url,\n",
    "  ",
    abstract_expr,
    " AS abstract,\n",
    "  ",
    authors_expr,
    " AS authors,\n",
    "  ",
    orcids_expr,
    " AS author_orcids,\n",
    "  ",
    publisher_expr,
    " AS publisher,\n",
    "  ",
    issn_l_expr,
    " AS issn_l,\n",
    "  ",
    issns_expr,
    " AS issns,\n",
    "  ",
    language_expr,
    " AS language,\n",
    "  ",
    pubdate_expr,
    " AS publication_date,\n",
    "  ",
    oa_is_expr,
    " AS is_oa,\n",
    "  ",
    oa_status_expr,
    " AS oa_status,\n",
    "  ",
    keywords_expr,
    " AS keywords,\n",
    "  ",
    cited_by_expr,
    " AS cited_by_count\n",
    "FROM src"
  )

  split_name <- function(name) {
    if (is.null(name) || is.na(name) || !nzchar(name)) {
      return(list(given = "", family = ""))
    }
    if (grepl(",", name, fixed = TRUE)) {
      fam <- trimws(sub(",.*$", "", name))
      giv <- trimws(sub("^[^,]*,", "", name))
      return(list(given = giv, family = fam))
    }
    parts <- strsplit(name, "\\\\s+")[[1]]
    parts <- parts[nzchar(parts)]
    if (!length(parts)) {
      return(list(given = "", family = ""))
    }
    family <- parts[length(parts)]
    given <- if (length(parts) > 1) {
      paste(parts[1:(length(parts) - 1)], collapse = " ")
    } else {
      ""
    }
    list(given = given, family = family)
  }

  `%||%` <- function(a, b) {
    if (is.null(a) || length(a) == 0 || is.na(a) || !nzchar(as.character(a))) {
      b
    } else {
      a
    }
  }

  wrote <- 0L
  n_chunks <- if (n_total == 0) 0L else ceiling(n_total / chunk_size)
  for (k in seq_len(n_chunks)) {
    offset <- (k - 1L) * chunk_size
    q <- sprintf(
      "%s LIMIT %d OFFSET %d",
      select_sql,
      as.integer(chunk_size),
      as.integer(offset)
    )
    df <- DBI::dbGetQuery(con, q)
    if (!nrow(df)) {
      next
    }

    items <- vector("list", nrow(df))
    sanitize_item <- function(x) {
      # Remove NULLs and NA scalars recursively
      if (is.list(x)) {
        out <- list()
        for (nm in names(x)) {
          val <- x[[nm]]
          if (is.null(val)) {
            next
          }
          if (is.atomic(val) && length(val) == 1 && is.na(val)) {
            next
          }
          # Truncate abstract to 700 characters (post-sanitization handles encoding)
          if (identical(nm, "abstract") && is.character(val) && length(val)) {
            val[is.na(val)] <- ""
            val <- substr(val, 1L, 700L)
          }
          # Clean author objects: drop empty given/family and NA ORCID
          if (nm == "author" && is.list(val)) {
            auths <- list()
            for (a in val) {
              if (!is.list(a)) {
                next
              }
              # Drop NA ORCID
              if (
                !is.null(a$ORCID) &&
                  (is.na(a$ORCID) || identical(a$ORCID, "NA"))
              ) {
                a$ORCID <- NULL
              }
              # Ensure given/family are strings (not NA)
              if (!is.null(a$given) && is.na(a$given)) {
                a$given <- ""
              }
              if (!is.null(a$family) && is.na(a$family)) {
                a$family <- ""
              }
              auths[[length(auths) + 1L]] <- a
            }
            out$author <- auths
            next
          }
          out[[nm]] <- sanitize_item(val)
        }
        return(out)
      }
      if (is.atomic(x)) {
        if (is.character(x)) {
          # Replace NA with empty strings
          x[is.na(x)] <- ""
          # Convert to UTF-8 and drop invalid bytes
          x <- tryCatch(
            suppressWarnings(iconv(x, from = "", to = "UTF-8", sub = "")),
            error = function(e) x
          )
          # Remove control characters and normalize whitespace
          x <- gsub("[[:cntrl:]]", " ", x, perl = TRUE)
          x <- gsub("\\s+", " ", x, perl = TRUE)
          x <- trimws(x)
        } else if (is.logical(x)) {
          x[is.na(x)] <- FALSE
        }
      }
      x
    }
    for (i in seq_len(nrow(df))) {
      rec <- df[i, , drop = FALSE]
      pages <- if (
        !is.na(rec$first_page) &&
          nzchar(rec$first_page) &&
          !is.na(rec$last_page) &&
          nzchar(rec$last_page)
      ) {
        paste0(rec$first_page, "-", rec$last_page)
      } else {
        ""
      }
      # Map to CSL JSON type (favoring article-journal over article)
      t <- tolower(paste(rec$type, collapse = " "))
      vt <- tolower(paste(rec$venue_type, collapse = " "))
      csl_type <-
        if (grepl("posted-content|preprint|manuscript", t)) {
          "manuscript"
        } else if (
          grepl("journal-article|journal", t) ||
            grepl("journal", vt) ||
            nzchar(rec$venue %||% "")
        ) {
          "article-journal"
        } else if (
          grepl("proceedings|conference", t) ||
            grepl("proceedings|conference", vt)
        ) {
          "paper-conference"
        } else if (grepl("book", t)) {
          "book"
        } else {
          "article-journal"
        }
      # Authors (+ ORCID if present)
      auths <- list()
      orcids <- if (!is.null(rec$author_orcids[[1]])) {
        as.character(rec$author_orcids[[1]])
      } else {
        NULL
      }
      if (!is.null(rec$authors[[1]])) {
        for (idx in seq_along(rec$authors[[1]])) {
          nm <- as.character(rec$authors[[1]][[idx]])
          sp <- split_name(nm)
          a <- list(given = sp$given, family = sp$family)
          if (
            !is.null(orcids) && idx <= length(orcids) && nzchar(orcids[[idx]])
          ) {
            a$ORCID <- orcids[[idx]]
          }
          auths[[length(auths) + 1L]] <- a
        }
      }
      # issued date-parts (prefer full publication_date if present)
      issued_parts <- NULL
      if (!is.null(rec$publication_date) && nzchar(rec$publication_date)) {
        dp <- strsplit(as.character(rec$publication_date), "-")[[1]]
        nums <- suppressWarnings(as.integer(dp))
        nums <- nums[!is.na(nums)]
        if (length(nums) >= 1) issued_parts <- as.list(nums)
      }
      if (is.null(issued_parts)) {
        issued_parts <- as.list(stats::na.omit(as.integer(rec$year)))
      }
      # keywords
      keyword_val <- NULL
      if (!is.null(rec$keywords[[1]]) && length(rec$keywords[[1]]) > 0) {
        kw <- as.character(rec$keywords[[1]])
        kw <- kw[nzchar(kw)]
        if (length(kw)) keyword_val <- paste(kw, collapse = "; ")
      }
      # ISSN
      issn_val <- if (!is.null(rec$issn_l) && nzchar(rec$issn_l)) {
        rec$issn_l
      } else if (!is.null(rec$issns[[1]]) && length(rec$issns[[1]]) > 0) {
        paste(as.character(rec$issns[[1]]), collapse = ",")
      } else {
        ""
      }
      # Note field aggregating OA/citation info
      note_val <- NULL
      if (
        !is.null(rec$is_oa) ||
          !is.null(rec$oa_status) ||
          !is.null(rec$cited_by_count)
      ) {
        parts_note <- c()
        if (!is.null(rec$is_oa) && !is.na(rec$is_oa)) {
          parts_note <- c(parts_note, paste0("OA:", as.character(rec$is_oa)))
        }
        if (!is.null(rec$oa_status) && nzchar(rec$oa_status)) {
          parts_note <- c(parts_note, paste0("OA_status:", rec$oa_status))
        }
        if (!is.null(rec$cited_by_count) && !is.na(rec$cited_by_count)) {
          parts_note <- c(parts_note, paste0("Citations:", rec$cited_by_count))
        }
        if (length(parts_note)) note_val <- paste(parts_note, collapse = "; ")
      }
      it <- list(
        type = csl_type,
        id = rec$id %||% "",
        title = rec$title %||% ""
      )
      if (length(auths)) {
        it$author <- auths
      }
      if (!is.null(issued_parts) && length(issued_parts) > 0) {
        it$issued <- list("date-parts" = list(issued_parts))
      }
      if (nzchar(rec$venue %||% "")) {
        it[["container-title"]] <- rec$venue
      }
      if (nzchar(rec$volume %||% "")) {
        it$volume <- rec$volume
      }
      if (nzchar(rec$number %||% "")) {
        it$issue <- rec$number
      }
      if (nzchar(pages)) {
        it$page <- pages
      }
      # DOI: normalize to bare DOI (no resolver prefix)
      if (nzchar(rec$doi %||% "")) {
        doi_raw <- as.character(rec$doi %||% "")
        doi_norm <- tryCatch(
          extract_doi(doi_raw, non_doi_value = "", normalize = TRUE, what = "doi"),
          error = function(e) sub("^(?i)https?://(dx\\.)?doi\\.org/", "", doi_raw)
        )
        if (nzchar(doi_norm)) it$DOI <- doi_norm
      }
      # URL: avoid duplicating a DOI URL when DOI already present
      if (nzchar(rec$url %||% "")) {
        url_val <- as.character(rec$url)
        if (!is.null(it$DOI) && grepl("^(?i)https?://(dx\\.)?doi\\.org/", url_val)) {
          # Skip DOI resolver URL if DOI field is present
        } else {
          it$URL <- url_val
        }
      }
      if (nzchar(rec$abstract %||% "")) {
        it$abstract <- rec$abstract
      }
      if (nzchar(rec$publisher %||% "")) {
        it$publisher <- rec$publisher
      }
      if (nzchar(issn_val)) {
        it$ISSN <- issn_val
      }
      if (nzchar(rec$language %||% "")) {
        it$language <- rec$language
      }
      if (!is.null(keyword_val)) {
        it$keyword <- keyword_val
      }
      if (!is.null(note_val)) {
        it$note <- note_val
      }
      items[[i]] <- sanitize_item(it)
    }

    # Write this chunk as its own CSL JSON array file
    chunk_file <- file.path(output, sprintf("chunk_%d.json", k))
    jsonlite::write_json(
      items,
      path = chunk_file,
      auto_unbox = TRUE,
      pretty = FALSE
    )
    wrote <- wrote + length(items)
    if (verbose) {
      message(sprintf(
        "Wrote %s (%d/%d records)",
        basename(chunk_file),
        wrote,
        n_total
      ))
    }
  }
  if (verbose) {
    message(
      "Done: ",
      wrote,
      " records across ",
      n_chunks,
      " files in ",
      normalizePath(output)
    )
  }
  invisible(normalizePath(output))
}


#' Convert CSL JSON (file or directory) via Pandoc
#'
#' Converts CSL JSON with Pandoc into one of: BibTeX, BibLaTeX, Docx, Markdown,
#' LaTeX, or PDF. Behavior depends on `to`:
#' - `bibtex`/`biblatex`: creates bibliography files. For a directory of chunks,
#'   writes `chunk_*.bib` into the directory given by `output`. For a single
#'   file, writes the specified `output` (appends `.bib` if missing).
#' - `docx`/`markdown`/`latex`/`pdf`: renders a formatted references document
#'   using citeproc. For a directory of chunks, writes `references.<ext>` inside
#'   `output`. For a single file, writes to `output` (appends extension if
#'   missing).
#'
#' @param csljson Path to a CSL JSON file (array) or a directory created by
#'   `corpus_to_csljson()` containing `chunk_*.json` files.
#' @param output Output path. For `bib*` with a file input, this is the target
#'   `.bib` file (extension added if missing). For `bib*` with a directory
#'   input, this is the output directory. For formatted references (`docx`,
#'   `markdown`, `latex`, `pdf`), this is the output file (file input) or the
#'   output directory (dir input; file will be `references.<ext>` within).
#' @param to One of `"biblatex"`, `"bibtex"`, `"docx"`, `"markdown"`,
#'   `"latex"`, `"html"`, or `"pdf"`.
#' @param from Source format; defaults to "csljson".
#' @param overwrite Logical; overwrite existing output file(s). Defaults to FALSE.
#' @param verbose Print progress messages.
#' @param references_csl Optional path to a CSL style file (e.g., apa.csl). If
#'   NULL, Pandoc's default style is used.
#'
#' @return Invisibly returns the created file path(s).
#'
#' @details Requires Pandoc to be available. In RStudio, a bundled Pandoc is
#' usually available; otherwise install Pandoc and ensure it is on PATH.
#'
#' @md
#'
#' @export
csljson_convert_pandoc <- function(
  csljson,
  output,
  to = c("biblatex", "bibtex", "docx", "markdown", "latex", "html", "pdf"),
  from = "csljson",
  overwrite = FALSE,
  verbose = TRUE,
  references_csl = NULL,
  pdf_engine = "xelatex",
  pdf_mainfont = NULL,
  pdf_sansfont = NULL,
  pdf_monofont = NULL,
  pdf_cjk_mainfont = NULL,
  pdf_cjk_options = NULL
) {
  to <- match.arg(to)
  if (!file.exists(csljson)) {
    stop("`csljson` does not exist: ", csljson)
  }
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop(
      "Package 'rmarkdown' is required for Pandoc conversion. Please install it."
    )
  }
  if (!rmarkdown::pandoc_available()) {
    stop(
      "Pandoc is not available. Install Pandoc or use RStudio (bundled Pandoc)."
    )
  }
  # If a directory is provided, handle chunked inputs
  if (dir.exists(csljson)) {
    in_dir <- normalizePath(csljson, mustWork = TRUE)
    chunk_files <- list.files(
      in_dir,
      pattern = "^chunk_\\d+\\.json$",
      full.names = TRUE
    )
    if (!length(chunk_files)) {
      stop("No chunk_*.json files found in ", csljson)
    }
    if (to %in% c("bibtex", "biblatex")) {
      # Ensure output is a directory
      out_dir <- output
      if (file.exists(out_dir)) {
        if (!dir.exists(out_dir)) {
          stop(
            "`output` must be a directory when converting a directory of chunks."
          )
        }
      } else {
        dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      }
      out_dir <- normalizePath(out_dir, mustWork = TRUE)
      ext <- switch(to, bibtex = ".bib", biblatex = ".bib")
      out_files <- character(length(chunk_files))
      for (i in seq_along(chunk_files)) {
        in_f <- normalizePath(chunk_files[i], mustWork = TRUE)
        base <- sub("\\.json$", "", basename(in_f))
        out_f <- file.path(out_dir, paste0(base, ext))
        if (file.exists(out_f)) {
          if (!overwrite) {
            stop(
              "Output file exists: ",
              out_f,
              ". Set overwrite = TRUE to replace."
            )
          }
          unlink(out_f)
        }
        # Normalize and sanitize JSON to avoid edge cases that can stall Pandoc
        in_use <- in_f
        tmp_in <- tempfile(fileext = ".json")
        sanitized <- FALSE
        try(
          {
            j <- jsonlite::fromJSON(in_f, simplifyVector = FALSE)
            if (is.list(j)) {
              # If it's an array of items, iterate and drop excessively long abstracts
              if (!is.null(j) && length(j) > 0 && is.null(names(j))) {
                for (kk in seq_along(j)) {
                  it <- j[[kk]]
                  if (
                    is.list(it) &&
                      !is.null(it$abstract) &&
                      is.character(it$abstract)
                  ) {
                    ab <- it$abstract
                    if (
                      length(ab) == 1L && nchar(ab, allowNA = FALSE) > 10000
                    ) {
                      it$abstract <- NULL
                      j[[kk]] <- it
                      sanitized <- TRUE
                    }
                  }
                }
              } else if (!is.null(j$abstract) && is.character(j$abstract)) {
                if (nchar(j$abstract, allowNA = FALSE) > 10000) {
                  j$abstract <- NULL
                  sanitized <- TRUE
                }
              }
            }
            # Always re-serialize to normalized JSON; use sanitized content if applicable
            jsonlite::toJSON(j, auto_unbox = TRUE) |> writeLines(con = tmp_in)
            in_use <- tmp_in
          },
          silent = TRUE
        )
        if (verbose) {
          message(
            "Converting with pandoc: ",
            basename(in_f),
            " -> ",
            basename(out_f),
            " (",
            to,
            ")",
            if (sanitized) " [sanitized]" else ""
          )
        }
        rmarkdown::pandoc_convert(
          input = in_use,
          to = to,
          from = "csljson",
          output = out_f
        )
        out_files[i] <- out_f
      }
      return(invisible(normalizePath(out_files, mustWork = FALSE)))
    }
    if (to %in% c("docx", "markdown", "latex", "html", "pdf")) {
      # Build pandoc options: citeproc + multiple --bibliography flags
      bib_opts <- paste0(
        "--bibliography=",
        normalizePath(chunk_files, mustWork = TRUE)
      )
      extra <- c("--citeproc", bib_opts)
      if (identical(to, "html")) {
        # Ensure UTF-8 meta charset and full HTML head/body
        extra <- c(extra, "--standalone")
      }
      if (identical(to, "pdf")) {
        # Use Unicode-capable engine (default xelatex) and optional fonts
        if (!is.null(pdf_engine)) extra <- c(extra, paste0("--pdf-engine=", pdf_engine))
        add_font <- function(var, val) {
          if (!is.null(val) && nzchar(val)) extra <<- c(extra, "-V", paste0(var, "=", val))
        }
        add_font("mainfont", pdf_mainfont)
        add_font("sansfont", pdf_sansfont)
        add_font("monofont", pdf_monofont)
        add_font("CJKmainfont", pdf_cjk_mainfont)
        add_font("CJKoptions", pdf_cjk_options)
      }
      if (identical(to, "pdf")) {
        # Use a Unicode-capable LaTeX engine
        extra <- c(extra, "--pdf-engine=xelatex")
      }
      if (!is.null(references_csl)) {
        extra <- c(extra, paste0("--csl=", references_csl))
      }
      # Prepare a minimal markdown that asks citeproc to include all entries
      # via YAML nocite and provides a refs placeholder
      md <- tempfile(fileext = ".md")
      cat(
        paste0(
          "---\n",
          "nocite: \"@*\"\n",
          "---\n\n",
          "# References\n\n",
          "::: {#refs}\n",
          ":::\n"
        ),
        file = md
      )
      # Determine output file inside the output directory
      out_dir <- output
      # Ensure `output` is a directory path (create if missing; error if a file)
      if (file.exists(out_dir) && !dir.exists(out_dir)) {
        stop(
          "`output` must be a directory when converting a directory of chunks."
        )
      }
      if (!dir.exists(out_dir)) {
        ok <- dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
        if (!ok || !dir.exists(out_dir)) {
          stop("Could not create output directory: ", out_dir)
        }
      }
      ext <- switch(
        to,
        docx = ".docx",
        markdown = ".md",
        latex = ".tex",
        html = ".html",
        pdf = ".pdf"
      )
      # Normalize out_dir to absolute path for Pandoc's working directory
      out_dir <- normalizePath(out_dir, mustWork = TRUE)
      refs_out <- file.path(out_dir, paste0("references", ext))
      # Only delete the specific file if it exists and overwrite is TRUE
      if (file.exists(refs_out)) {
        if (!overwrite) {
          stop(
            "Output file exists: ",
            refs_out,
            ". Set overwrite = TRUE to replace."
          )
        }
        unlink(refs_out)
      }
      if (verbose) {
        message(
          "Rendering formatted references: ",
          basename(refs_out),
          " (",
          to,
          ")"
        )
      }
      rmarkdown::pandoc_convert(
        input = md,
        to = to,
        from = "markdown",
        output = refs_out,
        options = c(extra)
      )
      # Post-process Markdown to remove Pandoc fenced divs for a cleaner .md
      if (identical(to, "markdown")) {
        try({
          txt <- readLines(refs_out, warn = FALSE, encoding = "UTF-8")
          keep <- !grepl("^:{3,}\\s*(\\{.*\\})?$", txt)
          writeLines(txt[keep], refs_out, useBytes = TRUE)
        }, silent = TRUE)
      }
      return(invisible(normalizePath(refs_out, mustWork = FALSE)))
    }
    stop("Unsupported 'to' value: ", to)
  }
  # Single file case
  input_file <- normalizePath(csljson, mustWork = TRUE)
  if (to %in% c("bibtex", "biblatex")) {
    out_file <- output
    if (nzchar(out_file) && identical(tools::file_ext(out_file), "")) {
      out_file <- paste0(out_file, ".bib")
    }
    out_dir <- dirname(out_file)
    if (!identical(out_dir, ".") && !dir.exists(out_dir)) {
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    }
    if (file.exists(out_file)) {
      if (!overwrite) {
        stop("Output file exists: ", out_file)
      }
      unlink(out_file)
    }
    if (verbose) {
      message(
        "Converting with pandoc: ",
        basename(input_file),
        " -> ",
        basename(out_file),
        " (",
        to,
        ")"
      )
    }
    # Normalize JSON through jsonlite for single-file as well
    in_use <- input_file
    tmp_in <- tempfile(fileext = ".json")
    try(
      {
        j <- jsonlite::fromJSON(input_file, simplifyVector = FALSE)
        jsonlite::toJSON(j, auto_unbox = TRUE) |> writeLines(con = tmp_in)
        in_use <- tmp_in
      },
      silent = TRUE
    )
    rmarkdown::pandoc_convert(
      input = in_use,
      to = to,
      from = "csljson",
      output = out_file
    )
    return(invisible(normalizePath(out_file, mustWork = FALSE)))
  }
  if (to %in% c("docx", "markdown", "latex", "html", "pdf")) {
    extra <- c("--citeproc", paste0("--bibliography=", input_file))
    if (identical(to, "html")) {
      # Ensure UTF-8 meta charset and full HTML head/body
      extra <- c(extra, "--standalone")
    }
    if (identical(to, "pdf")) {
      # Use Unicode-capable engine (default xelatex) and optional fonts
      if (!is.null(pdf_engine)) extra <- c(extra, paste0("--pdf-engine=", pdf_engine))
      add_font <- function(var, val) {
        if (!is.null(val) && nzchar(val)) extra <<- c(extra, "-V", paste0(var, "=", val))
      }
      add_font("mainfont", pdf_mainfont)
      add_font("sansfont", pdf_sansfont)
      add_font("monofont", pdf_monofont)
      add_font("CJKmainfont", pdf_cjk_mainfont)
      add_font("CJKoptions", pdf_cjk_options)
    }
    if (identical(to, "pdf")) {
      # Use a Unicode-capable LaTeX engine
      extra <- c(extra, "--pdf-engine=xelatex")
    }
    if (!is.null(references_csl)) {
      extra <- c(extra, paste0("--csl=", references_csl))
    }
    md <- tempfile(fileext = ".md")
    cat(
      paste0(
        "---\n",
        "nocite: \"@*\"\n",
        "---\n\n",
        "# References\n\n",
        "::: {#refs}\n",
        ":::\n"
      ),
      file = md
    )
    refs_out <- output
    if (identical(tools::file_ext(refs_out), "")) {
      ext <- switch(
        to,
        docx = ".docx",
        markdown = ".md",
        latex = ".tex",
        html = ".html",
        pdf = ".pdf"
      )
      refs_out <- paste0(refs_out, ext)
    }
    rd <- dirname(refs_out)
    if (!identical(rd, ".") && !dir.exists(rd)) {
      dir.create(rd, recursive = TRUE, showWarnings = FALSE)
    }
    # Use absolute output path to avoid Pandoc writing into a temp dir
    refs_out <- normalizePath(refs_out, mustWork = FALSE)
    if (file.exists(refs_out)) {
      if (!overwrite) {
        stop("Output file exists: ", refs_out)
      }
      unlink(refs_out)
    }
    if (verbose) {
      message(
        "Rendering formatted references: ",
        basename(refs_out),
        " (",
        to,
        ")"
      )
    }
    rmarkdown::pandoc_convert(
      input = md,
      to = to,
      from = "markdown",
      output = refs_out,
      options = c(extra)
    )
    # Post-process Markdown to remove Pandoc fenced divs for a cleaner .md
    if (identical(to, "markdown")) {
      try({
        txt <- readLines(refs_out, warn = FALSE, encoding = "UTF-8")
        keep <- !grepl("^:{3,}\\s*(\\{.*\\})?$", txt)
        writeLines(txt[keep], refs_out, useBytes = TRUE)
      }, silent = TRUE)
    }
    return(invisible(normalizePath(refs_out, mustWork = FALSE)))
  }
  stop("Unsupported 'to' value: ", to)
}


#' One-shot export via CSL JSON + Pandoc
#'
#' Convenience wrapper that maps a corpus to CSL JSON, then converts it to the
#' desired output format via Pandoc.
#'
#' @param corpus Arrow Dataset/Table or data.frame/tibble of works.
#' @param output Path to the final file (e.g., `corpus.bib`).
#' @param to Target format passed to Pandoc (e.g., `"bibtex"`, `"biblatex"`).
#' @param csl_tmp Optional path for a temporary CSL JSON directory. If `NULL`, a
#'   temporary directory is used and removed afterwards.
#' @param ... Additional arguments passed to `corpus_to_csljson()` (e.g., `chunk_size`).
#'
#' @return Invisibly returns `normalizePath(output)`.
#'
#' @export
corpus_export_via_pandoc <- function(
  corpus,
  output,
  to = c("bibtex", "biblatex"),
  csl_tmp = NULL,
  ...
) {
  to <- match.arg(to)
  remove_tmp <- FALSE
  if (is.null(csl_tmp)) {
    csl_tmp <- tempfile(pattern = "csljson_")
    dir.create(csl_tmp, recursive = TRUE, showWarnings = FALSE)
    remove_tmp <- TRUE
  }
  corpus_to_csljson(corpus, csl_tmp, ...)
  on.exit(
    if (remove_tmp) {
      try(unlink(csl_tmp, recursive = TRUE, force = TRUE), silent = TRUE)
    },
    add = TRUE
  )
  csljson_convert_pandoc(csl_tmp, output, to = to)
  invisible(normalizePath(output))
}
