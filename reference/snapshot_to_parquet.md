# Convert OA snapshot to Parquet format

This function converts the OA (OpenAlex) snapshot data to Parquet
format, processing each `.gz` file individually. Existing output files
are skipped, allowing interrupted conversions to resume. On macOS, a
`.metadata_never_index` file is created in the output directory to
prevent Spotlight from indexing the parquet files.

## Usage

``` r
snapshot_to_parquet(
  snapshot_dir = file.path("", "Volumes", "openalex", "openalex-snapshot"),
  parquet_dir = file.path("", "Volumes", "openalex", "parquet"),
  data_sets = NULL,
  sample_size = 20,
  temp_directory = NULL,
  memory_limit = NULL,
  workers = NULL
)
```

## Arguments

- snapshot_dir:

  The directory path of the OA snapshot data. Default is
  `"Volumes/openalex/openalex-snapshot"`.

- parquet_dir:

  The directory path where the Parquet files will be saved. Default is
  `"Volumes/openalex/parquet"`.

- data_sets:

  A character vector specifying the data sets to process. Default is
  `NULL`, which processes all data sets.

- sample_size:

  Number of `.gz` files to sample for unified schema inference. Higher
  values give more accurate schemas but take longer. Default is `20`.
  Use `NULL` or `0` to use all files.

- temp_directory:

  Location of the temporary directory for DuckDB. Passed to each
  worker's DuckDB connection. Default is `NULL` (system default).

- memory_limit:

  DuckDB memory limit per worker (e.g., `"8GB"`). Default is `NULL`
  (DuckDB default).

- workers:

  Number of parallel workers for file conversion via
  [`future.apply::future_lapply()`](https://future.apply.futureverse.org/reference/future_lapply.html).
  Default is `NULL` (sequential processing).

## Details

The conversion proceeds in two stages for each data set:

1.  **Schema inference**: A sample of `.gz` files is read using DuckDB's
    `read_json_auto()` with `union_by_name = true` to infer a unified
    schema. This ensures all output parquet files have consistent column
    types.

2.  **Per-file conversion**: Each `.gz` file is converted individually
    to a `.parquet` file. When `workers > 1`, files are processed in
    parallel using
    [future::multisession](https://future.futureverse.org/reference/multisession.html),
    with each worker creating its own DuckDB connection.

Already-converted files (those with a matching `.parquet` output) are
automatically skipped, so the function can resume after interruption.

## Examples

``` r
if (FALSE) { # \dontrun{
# Convert all data sets in the default snapshot directory
snapshot_to_parquet()

# Convert specific data sets with parallel processing
snapshot_to_parquet(
  snapshot_dir = "/path/to/snapshot",
  data_sets = c("authors", "works"),
  workers = 4,
  memory_limit = "8GB"
)
} # }
```
