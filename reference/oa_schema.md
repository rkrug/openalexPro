# Get or refresh an OpenAlex entity schema

Returns the baseline column schema for an OpenAlex entity (used by
[`pro_request_parquet`](https://openalexpro.github.io/openalexPro/reference/pro_request_parquet.md)`(schema = "auto")`
to resolve ambiguous DuckDB JSON types), and optionally refreshes the
user-level cache from a local Parquet corpus.

## Usage

``` r
oa_schema(
  entity = NULL,
  parquet_dir = NULL,
  entities = "all",
  overwrite = FALSE,
  update = FALSE,
  verbose = TRUE
)
```

## Arguments

- entity:

  Character scalar. Entity name, e.g. `"works"`. Required when
  `update = FALSE`; ignored when `update = TRUE` and `entities != "all"`
  is a vector.

- parquet_dir:

  Character scalar. Root Parquet directory containing one sub-directory
  per entity, e.g. `"/Volumes/openalex/parquet"`. Required when
  `update = TRUE`; ignored otherwise.

- entities:

  Character vector or `"all"` (default). Entities to refresh when
  `update = TRUE`. `"all"` auto-discovers sub-directories of
  `parquet_dir`, excluding `*_aws` staging directories.

- overwrite:

  Logical. When `update = TRUE`, overwrite an existing cached CSV?
  Default `FALSE`.

- update:

  Logical. When `TRUE`, read schema from `parquet_dir` and write to the
  user cache. Default `FALSE`.

- verbose:

  Logical. Print progress messages? Default `TRUE`.

## Value

`update = FALSE`: a `data.frame` with columns `col_name` and `col_type`,
or `NULL` if no schema is found for `entity`.  
`update = TRUE`: the path to the schemata cache directory (invisibly).

## Resolution order (`update = FALSE`)

1.  User cache
    (`tools::R_user_dir("openalexPro","cache")/schemata/<entity>.csv`)

2.  Schemas bundled with the package
    (`inst/extdata/schemata/<entity>.csv`)

## Refreshing the cache (`update = TRUE`)

Reads the schema of each entity corpus from `parquet_dir` using DuckDB
and writes the result to the user cache. After updating, the new schema
is available to subsequent calls with `update = FALSE` and to
`pro_request_parquet(schema = "auto")`. Run periodically to pick up new
fields added by OpenAlex.

## See also

[`pro_request_parquet`](https://openalexpro.github.io/openalexPro/reference/pro_request_parquet.md)
for the `schema` parameter.
