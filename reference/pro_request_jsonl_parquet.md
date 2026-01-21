# Convert JSON files to Apache Parquet files

The function takes a directory of JSONL files as written from a call to
`pro_request_jsonl(...)` and converts it to a Apache Parquet files. Each
jsonl is processed individually, so there is no limit of the number of
records.

## Usage

``` r
pro_request_jsonl_parquet(
  input_jsonl = NULL,
  output = NULL,
  overwrite = FALSE,
  verbose = TRUE,
  progress = TRUE,
  delete_input = FALSE,
  sample_size = 1000
)
```

## Arguments

- input_jsonl:

  The directory of JSON files returned from
  `pro_request(..., json_dir = "FOLDER")`.

- output:

  output directory for the parquet dataset; default: temporary
  directory.

- overwrite:

  Logical indicating whether to overwrite `output`.

- verbose:

  Logical indicating whether to show a verbose information. Defaults to
  `TRUE`

- progress:

  Logical indicating whether to show a progress bar. Default `TRUE`.

- delete_input:

  Determines if the `input_jsonl` should be deleted afterwards. Defaults
  to `FALSE`.

- sample_size:

  Number of records to sample from each file when inferring the unified
  schema. Higher values give more accurate schema inference but use more
  memory. Default is 1000. Set to -1 to read all records (may be slow
  for large files).

## Value

The function does returns the output invisibly.

## Details

The value `page` as created in
[`pro_request_jsonl()`](https://rkrug.github.io/openalexPro/reference/pro_request_jsonl.md)
is used for partitioning. All jsonl files are combined into a single
Apache Parquet dataset, but can be filtered out by using the "page". As
an example:

1.  the subfolder in the `output` folder is called `Chunk_1`

2.  the page othe json file represents is `2`

3.  The resulting values for `page` will be `Chunk_1_2`

When starting the conversion, a file `00_in.progress` which is deleted
upon completion.

The function uses DuckDB to read the JSON files and to create the Apache
Parquet files. The function creates a DuckDB connection in memory and
reads the JSON files into DuckDB when needed. Then it creates a SQL
query to convert the JSON files to Apache Parquet files and to copy the
result to the specified directory.

To ensure consistent schemas across all Parquet files, the function
first infers a unified schema by sampling records from all JSONL files.
This prevents type mismatches (e.g., a column being `struct` in one file
but `string` in another) that would cause errors when reading the
combined Parquet dataset.
