# Snapshot Conversion: Schema Inference and Parquet Writing

## Overview

[`snapshot_to_parquet()`](https://rkrug.github.io/openalexPro/reference/snapshot_to_parquet.md)
converts the OpenAlex NDJSON snapshot (hundreds of gzip-compressed
files) into a Parquet dataset. This vignette explains the internal
mechanics in detail, focusing on the two-stage pipeline:

1.  **Schema inference** — derive a single, consistent column
    specification from a sample of source files.
2.  **Per-file conversion** — write each `.gz` file to a `.parquet` file
    using that specification.

Understanding these stages helps you tune parameters, interpret progress
messages, manage the schema cache, and use
[`infer_json_schema()`](https://rkrug.github.io/openalexPro/reference/infer_json_schema.md)
directly in your own workflows.

## Why a Unified Schema?

The OpenAlex snapshot stores data as NDJSON (newline-delimited JSON),
one record per line. JSON is schemaless: a field that appears as a
number in one file may be absent (and thus typed differently by
auto-inference) in another.

DuckDB’s `read_json_auto()` infers column types independently per file.
When the inferred types differ across files, reading a collection of
parquet files together with
[`arrow::open_dataset()`](https://arrow.apache.org/docs/r/reference/open_dataset.html)
or DuckDB’s `parquet_scan()` causes type-mismatch errors such as:

    Unsupported cast from string to struct using function cast

The solution is to **infer once, apply everywhere**: run type inference
on a sample of files, compute a single widened type for each column, and
write every parquet file with that fixed schema. All files in the
dataset then share an identical schema and can be read together without
errors.

## Stage 1 — Schema Inference

### Entry Point

[`snapshot_to_parquet()`](https://rkrug.github.io/openalexPro/reference/snapshot_to_parquet.md)
calls
[`infer_json_schema()`](https://rkrug.github.io/openalexPro/reference/infer_json_schema.md)
once per dataset before any conversion starts:

``` r
columns_clause <- infer_json_schema(
  con             = con,            # shared DuckDB connection
  files           = gz_files,       # all .gz files for this dataset
  sample_size     = sample_size,    # how many files to sample (default 20)
  extra_options   = ndjson_options, # dataset-specific DuckDB options
  verbose         = TRUE,
  schema_cache_dir = file.path(parquet_ds, ".schema_cache")
)
```

The result, `columns_clause`, is a string like:

    {'id': 'VARCHAR', 'display_name': 'VARCHAR', 'works_count': 'BIGINT', ...}

This is passed verbatim to DuckDB’s
[`read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html)
during conversion:

``` sql
COPY (SELECT * FROM read_json('file.gz', columns = {'id': 'VARCHAR', ...}))
TO 'file.parquet' (FORMAT PARQUET, COMPRESSION SNAPPY, ROW_GROUP_SIZE 100000)
```

### File Sampling

If `sample_size` is positive and smaller than the total number of files,
a random sample is drawn:

``` r
if (!is.null(sample_size) && sample_size > 0 && length(files) > sample_size) {
  files <- sample(files, sample_size)
}
```

A larger sample catches more type variations at the cost of more DuckDB
queries. For most datasets the default of 20 is sufficient; for `works`
(1981 files with heterogeneous schema evolution), 100–500 is safer.

### Per-File DESCRIBE

For each sampled file,
[`infer_json_schema()`](https://rkrug.github.io/openalexPro/reference/infer_json_schema.md)
runs a single DuckDB `DESCRIBE` query:

``` sql
DESCRIBE SELECT * FROM
  read_json_auto(['file.gz'], union_by_name = true, ignore_errors = true)
```

`ignore_errors = true` prevents individual malformed records (e.g. works
files containing `abstract_inverted_index` with duplicate case-variant
JSON keys) from aborting the query. The result is a data frame with one
row per column:

| column_name  | column_type |
|--------------|-------------|
| id           | VARCHAR     |
| display_name | VARCHAR     |
| works_count  | BIGINT      |
| …            | …           |

This is done **one file at a time** rather than in a bulk query across
all sampled files, avoiding the out-of-memory crash that occurs when
DuckDB opens hundreds of large `.gz` files simultaneously.

### Schema Merging and Type Widening

After all per-file schemas have been collected, `merge_schemas()`
combines them into a single unified schema. It applies the following
**type-widening rules** to each column, in order:

#### Rule 1 — All Identical

If every sampled file agrees on the same type, that type is kept
unchanged.

    # All files: 'id' = VARCHAR → unified: VARCHAR

#### Rule 2 — Complex Type Wins

If a column is a `STRUCT`, `LIST`, or `MAP` in at least one file and a
simpler type (e.g. `VARCHAR`, `BIGINT`) in others, the complex type is
chosen. This handles fields that are `null` in some files (inferred as
`VARCHAR` by DuckDB) but a structured object in others.

    # Some files: 'apc_paid' = VARCHAR (nulls only)
    # Other files: 'apc_paid' = STRUCT(value BIGINT, currency VARCHAR, ...)
    # → unified: STRUCT(value BIGINT, currency VARCHAR, ...)

#### Rule 3 — Richest STRUCT Wins

When multiple files infer different `STRUCT` definitions for the same
column (different number of fields), the STRUCT with the most fields is
chosen. This captures the widest set of subfields.

    # File A: 'location' = STRUCT(country VARCHAR)
    # File B: 'location' = STRUCT(country VARCHAR, city VARCHAR, lat DOUBLE)
    # → unified: STRUCT(country VARCHAR, city VARCHAR, lat DOUBLE)

#### Rule 4 — Widest Numeric Wins

For pure numeric conflicts, the widest type in the following order is
chosen:

    TINYINT < SMALLINT < INTEGER (= INT) < BIGINT < HUGEINT < FLOAT < DOUBLE

    # Some files: 'cited_by_count' = INTEGER
    # Other files: 'cited_by_count' = BIGINT
    # → unified: BIGINT

#### Rule 5 — Fallback to VARCHAR

Any conflict that does not match the above rules is resolved by falling
back to `VARCHAR`. This is intentionally conservative: VARCHAR can hold
any value and prevents conversion errors at the cost of losing type
specificity.

    # Some files: 'updated_date' = DATE
    # Other files: 'updated_date' = VARCHAR
    # → unified: VARCHAR

#### Column Order

Columns appear in **first-seen order** from the collected schemas (not
alphabetically). This preserves the natural field order of the OpenAlex
schema and maintains backward compatibility when the unified schema is
reused across runs.

### Special Case — `works` Dataset

The `works` dataset has two specific workarounds applied after schema
inference:

#### 1. Large object size

Individual work records (particularly those with long author lists) can
exceed DuckDB’s default JSON object size limit. The
`maximum_object_size` option is extended for schema inference and
conversion:

``` r
ndjson_options <- if (data_set == "works") {
  ", maximum_object_size=1000000000"   # 1 GB
} else {
  ""
}
```

#### 2. `abstract_inverted_index` stored as VARCHAR

OpenAlex encodes abstracts as an *inverted index*: a JSON object mapping
each word to the list of its positions, e.g.
`{"The": [0], "quick": [1], "as": [3], "As": [7]}`.

JSON keys are case-sensitive, so `"as"` and `"As"` are distinct. DuckDB,
however, folds struct field names to lowercase when auto-inferring
`STRUCT` types, causing a collision:

    Error: duplicate key "as"

After schema inference,
[`snapshot_to_parquet()`](https://rkrug.github.io/openalexPro/reference/snapshot_to_parquet.md)
overrides the inferred type for this column to `VARCHAR`:

``` r
columns_clause <- gsub(
  "'abstract_inverted_index':\\s*'[^']*'",
  "'abstract_inverted_index': 'VARCHAR'",
  columns_clause
)
```

With type `VARCHAR`, DuckDB reads the entire JSON value as a raw text
string without parsing its keys into struct fields, so no collision
occurs. The data is fully preserved. To access individual entries, parse
with `jsonlite`:

``` r
library(arrow)
library(jsonlite)

works <- open_dataset("parquet/works")
row   <- works |> filter(id == "W2741809807") |> collect()

aii   <- fromJSON(row$abstract_inverted_index[1])
# aii is now a named list: list("The" = 0, "quick" = 1, "as" = 3, "As" = 7)
```

## The Schema Cache

Schema inference is the slowest sequential step (~3 s per file × sample
size). For large datasets it can take several minutes. A two-level cache
avoids repeating this work.

### Cache Location

The cache lives in `<parquet_dir>/<dataset>/.schema_cache/`:

    parquet/
    └── works/
        ├── .schema_cache/
        │   ├── unified_schema.csv        ← level 1
        │   ├── 2024-01-15_part_000.csv   ← level 2 (one per sampled file)
        │   ├── 2024-01-15_part_001.csv
        │   └── ...
        ├── updated_date=2024-01-15/
        │   ├── part_000.parquet
        │   └── ...
        └── ...

Per-file cache filenames are derived from the source path: the
`updated_date=` hive prefix is stripped from the parent directory, and
the `.gz` extension is removed from the filename, giving names like
`2024-01-15_part_000.csv`. This makes each cache file directly traceable
to its source `.gz`.

### Level 1 — Unified Schema Cache

`unified_schema.csv` stores the final merged schema as a two-column CSV:

    col_name,col_type
    id,VARCHAR
    display_name,VARCHAR
    works_count,BIGINT
    ...

On any subsequent call to
[`infer_json_schema()`](https://rkrug.github.io/openalexPro/reference/infer_json_schema.md)
with the same cache directory, this file is loaded immediately and
returned — **no DuckDB queries are executed**. A message is printed:

    Loaded cached unified schema with 47 columns (delete .../unified_schema.csv to re-infer)

**To force re-inference**, delete `unified_schema.csv`:

``` bash
rm parquet/works/.schema_cache/unified_schema.csv
```

### Level 2 — Per-File Schema Cache

Each per-file `DESCRIBE` result is saved as a CSV immediately after
being computed. On a restart, files whose CSVs already exist are loaded
from disk instead of re-queried. This enables **mid-run resume**: if
inference is interrupted after 60 of 100 files, only the remaining 40
are re-queried.

### Pre-populating the Cache to Skip Inference

Because `unified_schema.csv` is checked first and returned immediately
when found, **you can place a known-good schema file in the cache
directory before running
[`snapshot_to_parquet()`](https://rkrug.github.io/openalexPro/reference/snapshot_to_parquet.md)**
to bypass inference entirely. This is useful when:

- You have already inferred the schema in a previous run and the
  snapshot has not changed structurally.
- You want to apply a hand-edited or externally-supplied schema.
- You are re-converting a subset of files and want to guarantee the same
  schema as the full dataset.

The simplest workflow is to copy the `unified_schema.csv` from a
previous successful run:

``` bash
# After a successful conversion, copy the schema to a safe location
cp parquet/works/.schema_cache/unified_schema.csv ~/schemas/works_schema.csv

# Start a new conversion (e.g. after downloading an updated snapshot)
# but first restore the cached schema to skip inference:
mkdir -p parquet/works/.schema_cache
cp ~/schemas/works_schema.csv parquet/works/.schema_cache/unified_schema.csv

# Now run conversion — schema inference will be skipped
snapshot_to_parquet(
  snapshot_dir  = "/Volumes/openalex/openalex-snapshot",
  parquet_dir   = "/Volumes/openalex/parquet",
  data_sets     = "works",
  workers       = 4,
  memory_limit  = "8GB"
)
```

You can also construct or modify `unified_schema.csv` in R:

``` r
schema <- read.csv("parquet/works/.schema_cache/unified_schema.csv")

# Inspect the schema
head(schema)
#         col_name              col_type
# 1             id               VARCHAR
# 2   display_name               VARCHAR
# 3    works_count                BIGINT
# ...

# Override a type if needed, e.g. force a column to VARCHAR
schema$col_type[schema$col_name == "some_column"] <- "VARCHAR"

# Write back — this will be loaded on the next run
write.csv(schema, "parquet/works/.schema_cache/unified_schema.csv",
          row.names = FALSE)
```

**Caution:** if the new snapshot added columns that are absent from the
cached schema, those columns will be silently ignored during conversion.
Delete `unified_schema.csv` and re-infer if you suspect the schema has
changed.

### When to Delete the Cache

| Situation                              | Action                                                        |
|----------------------------------------|---------------------------------------------------------------|
| Resuming an interrupted inference run  | Do nothing — cache handles this automatically                 |
| Skipping inference with a known schema | Place `unified_schema.csv` in `.schema_cache/` before running |
| Forcing fresh inference (new snapshot) | Delete `unified_schema.csv` only                              |
| Forcing inference from scratch         | Delete the entire `.schema_cache/` directory                  |
| Schema looks wrong / incomplete        | Delete `unified_schema.csv` and increase `sample_size`        |

**The Makefile `parquet` target** runs `clean_parquet` first, which
deletes the entire parquet directory including `.schema_cache/`. Every
`make parquet` run therefore always re-infers the schema from scratch.
The cache is most useful when calling
[`snapshot_to_parquet()`](https://rkrug.github.io/openalexPro/reference/snapshot_to_parquet.md)
directly from R to resume an interrupted conversion, or to intentionally
reuse a schema from a previous run.

## Stage 2 — Per-File Conversion

Once the `columns_clause` is ready,
[`snapshot_to_parquet()`](https://rkrug.github.io/openalexPro/reference/snapshot_to_parquet.md)
converts each `.gz` file individually using `convert_json_to_parquet()`:

``` sql
COPY (SELECT * FROM read_json('file.gz', columns = {'id': 'VARCHAR', ...}))
TO 'file.parquet' (FORMAT PARQUET, COMPRESSION SNAPPY, ROW_GROUP_SIZE 100000)
```

Key properties:

- **One DuckDB connection per worker**: each `future` worker opens its
  own connection, so there are no locking conflicts.
- **Snappy compression**: a good balance of speed and size.
- **Row group size of 100 000**: controls the granularity of predicate
  pushdown and memory use during reads.
- **Directory structure preserved**: output paths mirror the input hive
  partition structure (`updated_date=2024-01-15/part_000.parquet`), so
  the dataset is immediately usable with Arrow’s partition-aware reader.
- **Resume support**: already-present `.parquet` files are skipped
  before conversion starts, so an interrupted run can be restarted.

### Parallel Processing

Set `workers` to use multiple
[`future::multisession`](https://future.futureverse.org/reference/multisession.html)
workers:

``` r
snapshot_to_parquet(
  snapshot_dir  = "/Volumes/openalex/openalex-snapshot",
  parquet_dir   = "/Volumes/openalex/parquet",
  data_sets     = "works",
  workers       = 4,
  memory_limit  = "8GB",
  temp_directory = "/tmp"
)
```

Each worker gets its own DuckDB connection with the same `memory_limit`
and `temp_directory` settings. Schema inference always runs sequentially
on the main process (it uses a single shared connection).

## Using `infer_json_schema()` Directly

[`infer_json_schema()`](https://rkrug.github.io/openalexPro/reference/infer_json_schema.md)
is exported and can be used standalone for any set of NDJSON files, not
just OpenAlex snapshots:

``` r
library(DBI)
library(duckdb)
library(openalexPro)

# Open a DuckDB connection and load the JSON extension
con <- dbConnect(duckdb())
dbExecute(con, "LOAD json")

# Collect files
files <- list.files(
  "path/to/ndjson",
  pattern    = "\\.gz$",
  recursive  = TRUE,
  full.names = TRUE
)

# Infer schema from up to 50 files, cache in a dedicated directory
columns_clause <- infer_json_schema(
  con             = con,
  files           = files,
  sample_size     = 50,
  verbose         = TRUE,
  schema_cache_dir = "path/to/cache"
)

cat(columns_clause)
# {'id': 'VARCHAR', 'name': 'VARCHAR', 'count': 'BIGINT', ...}

# Use it in your own query
sql <- sprintf(
  "COPY (SELECT * FROM read_json('data.gz', columns = %s)) TO 'data.parquet'",
  columns_clause
)
dbExecute(con, sql)

dbDisconnect(con, shutdown = TRUE)
```

The `schema_cache_dir` argument accepts any writable directory. Per-file
CSVs are named `<parent_dir>_<filename_without_gz>.csv`; if the parent
directory does not follow the `updated_date=` convention the raw
directory name is used.

## Summary

| Step                  | Function                                                                                                                                        | Notes                                     |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------|
| Enumerate `.gz` files | [`list.files()`](https://rdrr.io/r/base/list.files.html)                                                                                        | all files in dataset directory            |
| Skip converted files  | internal                                                                                                                                        | resume support                            |
| Infer unified schema  | [`infer_json_schema()`](https://rkrug.github.io/openalexPro/reference/infer_json_schema.md)                                                     | per-file `DESCRIBE`, R-side merge         |
| — check L1 cache      |                                                                                                                                                 | `unified_schema.csv` → return immediately |
| — check L2 cache      |                                                                                                                                                 | per-file CSVs → skip DuckDB query         |
| — run DESCRIBE        |                                                                                                                                                 | one query per sampled file                |
| — widen types         | `merge_schemas()`                                                                                                                               | 5-rule precedence                         |
| — save caches         |                                                                                                                                                 | L2 per file, L1 after merge               |
| Apply works fix       | [`gsub()`](https://rdrr.io/r/base/grep.html) in [`snapshot_to_parquet()`](https://rkrug.github.io/openalexPro/reference/snapshot_to_parquet.md) | `abstract_inverted_index` → VARCHAR       |
| Convert files         | `convert_json_to_parquet()`                                                                                                                     | one per worker, SNAPPY, RG=100000         |
