# Look up records by ID using a pre-built index

This function retrieves specific records from a parquet corpus using an
index built by
[`build_corpus_index()`](https://rkrug.github.io/openalexPro/reference/build_corpus_index.md).
It reads only the necessary files and rows, making it much faster than
scanning the entire corpus.

## Usage

``` r
lookup_by_id(
  index_file,
  ids,
  selected = NULL,
  workers = NULL,
  output = NULL,
  verbose = TRUE
)
```

## Arguments

- index_file:

  Path to the index parquet file created by
  [`build_corpus_index()`](https://rkrug.github.io/openalexPro/reference/build_corpus_index.md).

- ids:

  Character vector of OpenAlex IDs to look up. Can be in long form
  (e.g., `"https://openalex.org/W2741809807"`) or short form (e.g.,
  `"W2741809807"`).

- selected:

  Path to the parquet dataset containing the selected indices,
  partitioned by `parquet_file` of the work. If `NULL`, not saved.

- workers:

  Number of parallel workers for reading corpus files. Default is `NULL`
  (sequential). If `> 1`, uses
  [`future.apply::future_lapply()`](https://future.apply.futureverse.org/reference/future_lapply.html)
  with
  [future::multisession](https://future.futureverse.org/reference/multisession.html).

- output:

  Path to an output directory for writing results as parquet files. If
  `NULL` (default), results are returned as a data frame. If set,
  filtered records are written directly to parquet (one file per source
  corpus file) without loading them into R memory. The directory must
  not already exist.

- verbose:

  If `TRUE`, print progress messages. Default: `TRUE`

## Value

If `output` is `NULL`, a data frame containing the matching records. If
`output` is set, the output directory path is returned invisibly.

## Details

The function first filters the index (a single parquet file) using
[`arrow::open_dataset()`](https://arrow.apache.org/docs/r/reference/open_dataset.html)
and
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
to find matching IDs. It then uses DuckDB to efficiently read only the
specific rows needed from each corpus parquet file, avoiding full file
scans.

When `output` is set, DuckDB writes the filtered rows directly to
parquet files using `COPY ... TO`, so the data never enters R memory.
This is essential for lookups involving millions of IDs.

## Examples

``` r
if (FALSE) { # \dontrun{
# Return results as data frame
records <- lookup_by_id(
  index_file = "works_id_index.parquet",
  ids = c("W2741809807", "W1234567890")
)

# Write results to parquet (for millions of IDs)
lookup_by_id(
  index_file = "works_id_index.parquet",
  ids = large_id_vector,
  output = "filtered_works",
  workers = 3
)
} # }
```
