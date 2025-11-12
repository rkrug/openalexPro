# Normalize parquet files

The function takes a directory of parquet files and normalizes the
schemata. **NB: All partitioning in the input parquet dataset will be
lost!**

## Usage

``` r
normalize_parquet(
  input_dir = NULL,
  output_dir = NULL,
  overwrite = FALSE,
  ROW_GROUP_SIZE = 10000,
  ROW_GROUPS_PER_FILE = 1,
  delete_input = FALSE
)
```

## Arguments

- input_dir:

  The directory with the parquet files or a parquet dataset.

- output_dir:

  parquet dataset with the normalized schemata. Non partitioned, but
  split into several files.

- overwrite:

  Determines if the uputput parquet database shlud be overwritten if it
  exists. Defauls to `FALSE`.

- ROW_GROUP_SIZE:

  Maximum number of rows per row group. Smaller sizes reduce memory
  usage, larger sizes improve compression. Defaults to `10000`. See:
  <https://duckdb.org/docs/sql/statements/copy#row_group_size> for
  details.

- ROW_GROUPS_PER_FILE:

  Number of row groups to include in each output Parquet file. Controls
  file size and write frequency. Defaults to `1` See:
  <https://duckdb.org/docs/sql/statements/copy#row_groups_per_file> for
  details.

- delete_input:

  Determines if the `inputdir` should be deleted afterwards. Defaults to
  `FALSE`.

## Value

The function does return the `output_dir`.

## Details

The function uses DuckDB to normalize the schemata. The function creates
a DuckDB connection in memory and reads the parquet files into DuckDB
when needed and re-writes it in a non-partitioned parquet database with
a normalized schemata.
