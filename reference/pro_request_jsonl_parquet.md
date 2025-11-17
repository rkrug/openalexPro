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
  delete_input = FALSE
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

- delete_input:

  Determines if the `input_jsonl` should be deleted afterwards. Defaults
  to `FALSE`.

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

The function uses DuckDB to read the JSON files and to create the Apache
Parquet files. The function creates a DuckDB connection in memory and
readsds the JSON files into DuckDB when needed. Then it creates a SQL
query to convert the JSON files to Apache Parquet files and to copy the
result to the specified directory.
