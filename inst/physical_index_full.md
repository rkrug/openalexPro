# Physical Arrow/Feather Index for Fast Random Access to Parquet Corpora

## 1. Introduction

This document provides a complete, package-ready description of how to create
and use a **physical index** for Parquet datasets using Arrow. Unlike logical
indexes (e.g., DuckDB indexes on ID), a **physical index** stores *exact byte
locations* (row group + row offset) inside each Parquet file. This enables:

- O(1)-like random access to individual rows  
- No full dataset scans  
- Fast retrieval of arbitrary subsets of rows by ID  
- Efficient extraction of text vectors (e.g. `title`, `abstract`)  

This approach is ideal when working with large OpenAlex corpora where:

- Parquet remains the canonical store  
- You want fast random access  
- You do *not* want to ingest data into DuckDB  
- You want fully reproducible, deterministic row resolution  

The document includes:

- Theory and architecture
- Full R code with roxygen2 documentation
- `@importFrom` tag completeness
- Examples for index creation, single-row retrieval, multi-row retrieval, and
  retrieval of text vectors
- Integration notes for R packages

---

## 2. Architecture Overview

### 2.1. What is a physical Parquet index?

A physical index stores **per-row pointers** into Parquet files:

| Field           | Meaning |
|----------------|---------|
| `id`           | Identifier for the work (e.g., OpenAlex `id`) |
| `doi`          | DOI (may be missing) |
| `parquet_file` | Relative path to Parquet file |
| `row_group`    | Zero-based row group index |
| `row_offset`   | Zero-based offset inside the row group |

Using this, you can resolve an ID → exact row on disk → load only that row
group → extract the desired row → retrieve all or selected columns.

### 2.2. Why use a physical index?

When filtering a Parquet dataset like:

```r
ds |> filter(id == "W12345") |> collect()
```

Arrow must scan **all row groups** because ID columns cannot be pruned via
min/max statistics. This is O(N).

With a physical index, retrieving one ID:

1. lookup in index: O(1)
2. read exactly one row group: O(size of row group)
3. extract only one row

Much faster, even for millions of rows.

### 2.3. Performance summary

| Method | Row-group scanning? | Speed |
|--------|---------------------|-------|
| `filter(id == ...)` | Yes (likely all) | Slow |
| DuckDB logical index | Yes (still scans Parquet) | Slow |
| **Physical Arrow index** | **No** | **Fast** |
| Full DuckDB ingestion + indexes | No (stored in DuckDB) | Fast but duplicates data |

The physical index keeps Parquet as canonical storage.

---

## 3. Index Creation Function

Below is the full package-ready function.

### 3.1. Full roxygen2-documented function

```r
#' Build a physical Arrow index for a Parquet corpus
#'
#' @description
#' Construct a *physical index* for a Parquet dataset by recording, for each
#' row, its Parquet file, row group, and row offset. This enables O(1)-like
#' random access to individual works without scanning the entire dataset.
#'
#' @param parquet_dir Character scalar. Directory containing Parquet files.
#'   All `*.parquet` files under this directory (recursively) are included.
#'
#' @param out_file Character scalar. Path for the output Feather index file.
#'   Defaults to `"id_index.feather"` inside `parquet_dir`.
#'
#' @param id_col Character scalar. Name of the ID column in the Parquet files.
#'
#' @param doi_col Character scalar. Name of the DOI column in the Parquet files.
#'
#' @details
#' For each Parquet file, the function:
#'
#' - Reads only the ID and DOI columns.
#' - Extracts row-group metadata using `arrow::ParquetFileReader`.
#' - Maps each row to a `(row_group, row_offset)` pair.
#' - Stores the relative Parquet file path.
#'
#' This index allows direct random access of rows using
#' `arrow::read_parquet(..., row_groups=)` and indexing.
#'
#' @return Invisibly returns `out_file`.
#'
#' @examples
#' \dontrun{
#' build_physical_index(
#'   parquet_dir = "openalex/works",
#'   out_file = "openalex/id_index.feather",
#'   id_col = "id",
#'   doi_col = "doi"
#' )
#' }
#'
#' @export
#'
#' @importFrom arrow read_parquet ParquetFileReader write_feather
build_physical_index <- function(parquet_dir,
                                 out_file = file.path(parquet_dir, "id_index.feather"),
                                 id_col = "id",
                                 doi_col = "doi") {

  parquet_dir <- normalizePath(parquet_dir, mustWork = TRUE)

  files <- list.files(
    parquet_dir,
    pattern = "\.parquet$",
    full.names = TRUE,
    recursive = TRUE
  )
  if (!length(files))
    stop("No Parquet files found.", call. = FALSE)

  relpath <- function(x) {
    sub(paste0("^", parquet_dir, .Platform$file.sep), "", normalizePath(x))
  }

  results <- vector("list", length(files))
  k <- 0L

  for (f in files) {
    tbl <- arrow::read_parquet(f, col_select = c(id_col, doi_col))
    n <- nrow(tbl)
    if (!n) next

    reader <- arrow::ParquetFileReader$create(f)
    meta <- reader$metadata

    row_group <- integer(n)
    row_offset <- integer(n)

    idx <- 0L
    for (g in seq_len(meta$num_row_groups)) {
      rg <- meta$RowGroup(g - 1L)
      n_rg <- rg$num_rows
      if (n_rg > 0) {
        sel <- (idx + 1L):(idx + n_rg)
        row_group[sel] <- g - 1L
        row_offset[sel] <- 0:(n_rg - 1L)
      }
      idx <- idx + n_rg
    }

    k <- k + 1L
    results[[k]] <- data.frame(
      id = as.character(tbl[[id_col]]),
      doi = as.character(tbl[[doi_col]]),
      parquet_file = relpath(f),
      row_group = row_group,
      row_offset = row_offset,
      stringsAsFactors = FALSE
    )
  }

  index <- do.call(rbind, results)
  arrow::write_feather(index, out_file)
  invisible(out_file)
}
```

---

## 4. Retrieving Individual Rows by ID

```r
#' Retrieve a single row from a Parquet corpus using a physical index
#'
#' @description
#' Look up a row by its ID using a physical Arrow index. Only the necessary
#' row group is loaded from the Parquet file.
#'
#' @param id Character scalar. Work ID to retrieve.
#'
#' @param index A data.frame or Arrow table loaded from a Feather index.
#'
#' @param parquet_dir Root directory of the Parquet corpus.
#'
#' @return A one-row tibble.
#'
#' @export
#'
#' @importFrom arrow read_parquet
get_row_by_id <- function(id, index, parquet_dir) {
  ent <- index[index$id == id, ]
  if (!nrow(ent))
    stop("ID not found in index.", call. = FALSE)

  f <- file.path(parquet_dir, ent$parquet_file)
  rg <- arrow::read_parquet(f, row_groups = ent$row_group)

  rg[ent$row_offset + 1L, ]
}
```

---

## 5. Retrieving Text Columns for Multiple IDs

```r
#' Retrieve selected text columns for multiple IDs from Parquet using a physical index
#'
#' @description
#' Fetch specified columns (e.g. title, abstract) for multiple IDs without
#' scanning the entire Parquet dataset.
#'
#' @param ids Character vector of IDs.
#' @param index Physical index loaded into memory.
#' @param parquet_dir Root directory of Parquet files.
#' @param text_cols Character vector of column names to return.
#'
#' @return A tibble with one row per ID.
#'
#' @export
#'
#' @importFrom arrow read_parquet
#' @importFrom dplyr bind_rows
get_textvector_by_ids <- function(ids, index, parquet_dir, text_cols) {
  out <- vector("list", length(ids))

  for (i in seq_along(ids)) {
    id <- ids[i]
    ent <- index[index$id == id, ]

    if (!nrow(ent)) {
      out[[i]] <- tibble::tibble(id = id, !!!setNames(as.list(rep(NA, length(text_cols))), text_cols))
      next
    }

    f <- file.path(parquet_dir, ent$parquet_file)
    rg <- arrow::read_parquet(f, row_groups = ent$row_group,
                              col_select = c("id", text_cols))

    out[[i]] <- rg[ent$row_offset + 1L, ]
  }

  dplyr::bind_rows(out)
}
```

---

## 6. Example Workflow

```r
library(arrow)
library(dplyr)

# 1. Build index (one-time)
build_physical_index(
  parquet_dir = "openalex/corpus",
  out_file = "openalex/id_index.feather",
  id_col = "id",
  doi_col = "doi"
)

# 2. Load index
idx <- arrow::read_feather("openalex/id_index.feather")

# 3. Retrieve one work
x <- get_row_by_id(
  id = "https://openalex.org/W1234567",
  index = idx,
  parquet_dir = "openalex/corpus"
)

# 4. Retrieve multiple abstracts
abs <- get_textvector_by_ids(
  ids = c("W123", "W456", "W789"),
  index = idx,
  parquet_dir = "openalex/corpus",
  text_cols = c("title", "abstract")
)
```

---

## 7. Package Integration Notes

### Imports to add to `DESCRIPTION`

```
Imports:
    arrow,
    dplyr,
    tibble
```

### Add to your NAMESPACE via roxygen2

Generated automatically from tags.

### Directory structure

```
R/
  build_physical_index.R
  get_row_by_id.R
  get_textvector_by_ids.R
inst/
  docs/
    physical_index.md
```

---

## 8. Advantages and Limitations

### Advantages
- Fastest possible random access without using DuckDB as main store.
- Minimal memory footprint.
- Works with massive Parquet corpora.
- S3 bucket–compatible (index stores relative paths).

### Limitations
- If Parquet files change (added/removed rows), index must be rebuilt.
- Row groups vary in size, so loading a single row still loads ~100–200MB.

---

# End of Document
