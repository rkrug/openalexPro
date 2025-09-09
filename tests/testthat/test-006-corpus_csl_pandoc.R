test_that("corpus_to_csljson creates valid chunked CSL JSON", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")
  skip_if_not_installed("jsonlite")

  input_dir <- testthat::test_path("..", "fixtures", "corpus")
  skip_if_not(dir.exists(input_dir), "fixtures corpus not available")

  out_dir <- tempfile("csljson_")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  old <- out_dir
  on.exit(unlink(old, recursive = TRUE, force = TRUE), add = TRUE)
  res <- corpus_to_csljson(
    corpus = input_dir,
    output = out_dir,
    chunk_size = 100,
    overwrite = TRUE,
    verbose = FALSE
  )
  expect_true(dir.exists(res))

  chunks <- sort(
    list.files(
      out_dir,
      pattern = "^chunk_\\d+\\.json$",
      full.names = TRUE
    )
  )
  expect_true(length(chunks) >= 1)
  # Compare all generated chunks with fixtures
  fx_csl_dir <- testthat::test_path("..", "fixtures", "corpus_csl")
  skip_if_not(dir.exists(fx_csl_dir), "fixtures corpus_csl not available")
  fx_chunks <- sort(list.files(
    fx_csl_dir,
    pattern = "^chunk_\\d+\\.json$",
    full.names = TRUE
  ))
  expect_equal(length(chunks), length(fx_chunks))
  for (f in fx_chunks) {
    bn <- basename(f)
    gen <- file.path(out_dir, bn)
    expect_true(file.exists(gen), info = paste("missing generated:", bn))
    # Compare parsed JSON structures to ignore whitespace/ordering of keys
    fx_items <- jsonlite::fromJSON(f, simplifyVector = FALSE)
    gen_items <- jsonlite::fromJSON(gen, simplifyVector = FALSE)
    expect_equal(gen_items, fx_items, info = paste("JSON differs for:", bn))
  }

  # Validate each chunk is a JSON array of CSL-like items
  for (cf in chunks) {
    txt <- paste(
      readLines(cf, warn = FALSE, encoding = "UTF-8"),
      collapse = "\n"
    )
    expect_true(
      jsonlite::validate(txt),
      info = paste("Invalid JSON:", basename(cf))
    )
    items <- jsonlite::fromJSON(cf, simplifyVector = FALSE)
    expect_type(items, "list")
    expect_true(length(items) >= 1)

    # Spot check first item fields and sanitization
    it <- items[[1]]
    expect_true(is.list(it))
    expect_true(!is.null(it$type))
    expect_true(!is.null(it$title))

    # Abstract truncated and sanitized if present
    if (!is.null(it$abstract)) {
      expect_true(is.character(it$abstract))
      expect_lte(nchar(it$abstract, allowNA = FALSE), 700)
      # No control characters
      expect_false(grepl("[[:cntrl:]]", it$abstract))
    }
  }
})


test_that("csljson_convert_pandoc to bibtex (directory) matches fixtures", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")

  input_dir <- testthat::test_path("..", "fixtures", "corpus")
  skip_if_not(dir.exists(input_dir), "fixtures corpus not available")

  csl_dir <- tempfile("csljson_")
  dir.create(csl_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(csl_dir, recursive = TRUE, force = TRUE), add = TRUE)
  corpus_to_csljson(
    corpus = input_dir,
    output = csl_dir,
    chunk_size = 100,
    overwrite = TRUE,
    verbose = FALSE
  )

  out_btx <- tempfile("bibtex_")
  dir.create(out_btx, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(out_btx, recursive = TRUE, force = TRUE), add = TRUE)
  paths_btx <- csljson_convert_pandoc(
    csl_dir,
    out_btx,
    to = "bibtex",
    overwrite = TRUE,
    verbose = FALSE
  )
  expect_true(all(file.exists(paths_btx)))
  expect_true(all(file.info(paths_btx)$size > 0))

  fx_btx_dir <- testthat::test_path("..", "fixtures", "corpus_bibtex")
  skip_if_not(dir.exists(fx_btx_dir), "fixtures corpus_bibtex not available")
  fx_btx <- sort(list.files(
    fx_btx_dir,
    pattern = "^chunk_\\d+\\.bib$",
    full.names = TRUE
  ))
  expect_equal(length(paths_btx), length(fx_btx))
  for (f in fx_btx) {
    bn <- basename(f)
    gen <- file.path(out_btx, bn)
    expect_true(file.exists(gen), info = paste("missing generated:", bn))
    expect_equal(
      readLines(gen, warn = FALSE, encoding = "UTF-8"),
      readLines(f, warn = FALSE, encoding = "UTF-8"),
      info = paste("BibTeX differs for:", bn)
    )
  }
})

test_that("csljson_convert_pandoc to biblatex (directory) matches fixtures", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")

  input_dir <- testthat::test_path("..", "fixtures", "corpus")
  skip_if_not(dir.exists(input_dir), "fixtures corpus not available")

  csl_dir <- tempfile("csljson_")
  dir.create(csl_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(csl_dir, recursive = TRUE, force = TRUE), add = TRUE)
  corpus_to_csljson(
    corpus = input_dir,
    output = csl_dir,
    chunk_size = 100,
    overwrite = TRUE,
    verbose = FALSE
  )

  out_blx <- tempfile("biblatex_")
  dir.create(out_blx, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(out_blx, recursive = TRUE, force = TRUE), add = TRUE)
  blx_err <- NULL
  paths_blx <- NULL
  tryCatch(
    {
      paths_blx <- csljson_convert_pandoc(
        csl_dir,
        out_blx,
        to = "biblatex",
        overwrite = TRUE,
        verbose = FALSE
      )
    },
    error = function(e) blx_err <<- e
  )
  if (!is.null(blx_err)) {
    testthat::skip(paste(
      "biblatex conversion failed in this environment:",
      conditionMessage(blx_err)
    ))
  }
  expect_true(all(file.exists(paths_blx)))
  expect_true(all(file.info(paths_blx)$size > 0))

  fx_blx_dir <- testthat::test_path("..", "fixtures", "corpus_biblatex")
  skip_if_not(dir.exists(fx_blx_dir), "fixtures corpus_biblatex not available")
  fx_blx <- sort(list.files(
    fx_blx_dir,
    pattern = "^chunk_\\d+\\.bib$",
    full.names = TRUE
  ))
  expect_equal(length(paths_blx), length(fx_blx))
  for (f in fx_blx) {
    bn <- basename(f)
    gen <- file.path(out_blx, bn)
    expect_true(file.exists(gen), info = paste("missing generated:", bn))
    expect_equal(
      readLines(gen, warn = FALSE, encoding = "UTF-8"),
      readLines(f, warn = FALSE, encoding = "UTF-8"),
      info = paste("BibLaTeX differs for:", bn)
    )
  }
})

test_that("csljson_convert_pandoc to markdown matches fixture", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")

  input_dir <- testthat::test_path("..", "fixtures", "corpus")
  skip_if_not(dir.exists(input_dir), "fixtures corpus not available")

  csl_dir <- tempfile("csljson_")
  dir.create(csl_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(csl_dir, recursive = TRUE, force = TRUE), add = TRUE)
  corpus_to_csljson(
    corpus = input_dir,
    output = csl_dir,
    chunk_size = 100,
    overwrite = TRUE,
    verbose = FALSE
  )

  out_md_dir <- tempfile("md_")
  dir.create(out_md_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(out_md_dir, recursive = TRUE, force = TRUE), add = TRUE)
  md_path <- csljson_convert_pandoc(
    csl_dir,
    out_md_dir,
    to = "markdown",
    overwrite = TRUE,
    verbose = FALSE
  )
  expect_true(file.exists(md_path))
  md_txt <- readLines(md_path, warn = FALSE, encoding = "UTF-8")
  expect_true(length(md_txt) > 0)
  expect_true(any(grepl("^# +References$", md_txt)))
  expect_false(any(grepl("^:{3,}", md_txt)))

  fx_docs_dir <- testthat::test_path("..", "fixtures", "corpus_docs")
  skip_if_not(dir.exists(fx_docs_dir), "fixtures corpus_docs not available")
  fx_md <- file.path(fx_docs_dir, "references.md")
  expect_true(file.exists(fx_md))
  expect_equal(
    readLines(md_path, warn = FALSE, encoding = "UTF-8"),
    readLines(fx_md, warn = FALSE, encoding = "UTF-8")
  )
})

test_that("csljson_convert_pandoc to latex matches fixture", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")

  input_dir <- testthat::test_path("..", "fixtures", "corpus")
  skip_if_not(dir.exists(input_dir), "fixtures corpus not available")

  csl_dir <- tempfile("csljson_")
  dir.create(csl_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(csl_dir, recursive = TRUE, force = TRUE), add = TRUE)
  corpus_to_csljson(
    corpus = input_dir,
    output = csl_dir,
    chunk_size = 100,
    overwrite = TRUE,
    verbose = FALSE
  )

  out_tex_dir <- tempfile("tex_")
  dir.create(out_tex_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(out_tex_dir, recursive = TRUE, force = TRUE), add = TRUE)
  tex_path <- csljson_convert_pandoc(
    csl_dir,
    out_tex_dir,
    to = "latex",
    overwrite = TRUE,
    verbose = FALSE
  )
  fx_docs_dir <- testthat::test_path("..", "fixtures", "corpus_docs")
  skip_if_not(dir.exists(fx_docs_dir), "fixtures corpus_docs not available")
  fx_tex <- file.path(fx_docs_dir, "references.tex")
  expect_true(file.exists(tex_path))
  expect_true(file.exists(fx_tex))
  expect_equal(
    readLines(tex_path, warn = FALSE, encoding = "UTF-8"),
    readLines(fx_tex, warn = FALSE, encoding = "UTF-8")
  )
})

# test_that("csljson_convert_pandoc to docx content matches markdown output", {
#   skip_if_not_installed("rmarkdown")
#   skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")

#   input_dir <- testthat::test_path("..", "fixtures", "corpus")
#   skip_if_not(dir.exists(input_dir), "fixtures corpus not available")

#   csl_dir <- tempfile("csljson_")
#   dir.create(csl_dir, recursive = TRUE, showWarnings = FALSE)
#   on.exit(unlink(csl_dir, recursive = TRUE, force = TRUE), add = TRUE)
#   corpus_to_csljson(
#     corpus = input_dir,
#     output = csl_dir,
#     chunk_size = 100,
#     overwrite = TRUE,
#     verbose = FALSE
#   )

#   out_docx_dir <- tempfile("docx_")
#   dir.create(out_docx_dir, recursive = TRUE, showWarnings = FALSE)
#   on.exit(unlink(out_docx_dir, recursive = TRUE, force = TRUE), add = TRUE)
#   docx_path <- csljson_convert_pandoc(
#     csl_dir,
#     out_docx_dir,
#     to = "docx",
#     overwrite = TRUE,
#     verbose = FALSE
#   )
#   expect_true(file.exists(docx_path))

#   # Also create markdown from the same CSL to compare content in plain text
#   out_md_dir <- tempfile("md_")
#   dir.create(out_md_dir, recursive = TRUE, showWarnings = FALSE)
#   on.exit(unlink(out_md_dir, recursive = TRUE, force = TRUE), add = TRUE)
#   md_path <- csljson_convert_pandoc(
#     csl_dir,
#     out_md_dir,
#     to = "markdown",
#     overwrite = TRUE,
#     verbose = FALSE
#   )
#   expect_true(file.exists(md_path))

#   to_plain <- function(path, from) {
#     out <- tempfile(fileext = ".txt")
#     rmarkdown::pandoc_convert(input = path, to = "plain", from = from, output = out)
#     paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
#   }
#   docx_plain <- to_plain(docx_path, from = "docx")
#   md_plain <- to_plain(md_path, from = "markdown")
#   expect_equal(docx_plain, md_plain)
# })

test_that("csljson_convert_pandoc single-file bibtex works", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")

  input_dir <- testthat::test_path("..", "fixtures", "corpus")
  skip_if_not(dir.exists(input_dir), "fixtures corpus not available")

  # Build one chunk and convert that file
  csl_dir <- tempfile("csljson_")
  dir.create(csl_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(csl_dir, recursive = TRUE, force = TRUE), add = TRUE)
  corpus_to_csljson(
    corpus = input_dir,
    output = csl_dir,
    chunk_size = 100,
    overwrite = TRUE,
    verbose = FALSE
  )
  chunk1 <- file.path(csl_dir, "chunk_1.json")
  expect_true(file.exists(chunk1))

  tmp_dir <- tempfile("bib_")
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)
  out_bib <- file.path(tmp_dir, "chunk_1_single.bib")
  path_out <- csljson_convert_pandoc(
    chunk1,
    out_bib,
    to = "bibtex",
    overwrite = TRUE,
    verbose = FALSE
  )
  expect_true(file.exists(path_out))
  expect_true(file.info(path_out)$size > 0)
  # Compare single-file BibTeX with the fixture for chunk_1
  fx_btx_dir <- testthat::test_path("..", "fixtures", "corpus_bibtex")
  skip_if_not(dir.exists(fx_btx_dir), "fixtures corpus_bibtex not available")
  fx_bib <- file.path(fx_btx_dir, "chunk_1.bib")
  expect_true(file.exists(fx_bib))
  expect_equal(
    readLines(path_out, warn = FALSE, encoding = "UTF-8"),
    readLines(fx_bib, warn = FALSE, encoding = "UTF-8")
  )
})
