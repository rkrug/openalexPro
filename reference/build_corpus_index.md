# Build a Parquet index for fast ID lookups in a parquet corpus

This function creates a Parquet index that maps OpenAlex IDs to their
physical location in the parquet corpus. This enables fast random access
to specific records without scanning entire partitions.

## Usage

``` r
build_corpus_index(corpus_dir, memory_limit = NULL, workers = NULL)
```

## Arguments

- corpus_dir:

  Path to the parquet corpus directory.

- memory_limit:

  DuckDB memory limit (e.g., "20GB"). Default is `NULL`.

- workers:

  Number of parallel workers for Stage 1 indexing and DuckDB threads for
  Stage 2. Default is `NULL` (use all cores).

## Value

Invisibly returns the path to the created index.

## Details

The index file will be created in the same directory as the `corpus_dir`
and has to stay there for the lookup to function. Together with the
`corpus_dir`, the index file can be moved to any location.

The function is memory-efficient and can handle 300M+ records by using a
two-stage approach: first indexing each parquet file individually
(bounded memory per file), then combining into a single parquet index
file. This avoids loading the entire dataset at once. Stage 1 is
parallelized using
[`future.apply::future_lapply()`](https://future.apply.futureverse.org/reference/future_lapply.html)
and supports resuming if interrupted. On macOS, a
`.metadata_never_index` file is created in the temporary directory to
prevent Spotlight from indexing the parquet files during building.

The index contains the following columns:

- id:

  The OpenAlex ID

- id_block:

  Block number computed as `floor(numeric_id / 10000)`

- parquet_file:

  Relative path to the parquet file in the corpus

- file_row_number:

  Row number within the file (0-indexed)

## Examples

``` r
if (FALSE) { # \dontrun{
# Build partitioned index for OpenAlex IDs (fast O(1) lookup)
build_corpus_index(
  corpus_dir = "/Volumes/openalex/parquet/works",
  memory_limit = "20GB"
)
} # }
```
