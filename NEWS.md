# openalexPro 0.5.0

## New Features

### Snapshot Handling
* Added `prepare_snapshot()` function for setting up a directory with Makefile and documentation
  for managing OpenAlex snapshots.
* Added `Makefile.snapshot` in `inst/` for automating snapshot download, conversion, and indexing.
  Includes targets for `snapshot`, `arrow`, `arrow_index`, and automatic renaming of existing
  data with release dates.
* Added `snapshot_to_parquet()` function for converting OpenAlex snapshot NDJSON files to Parquet format
  using DuckDB. Supports memory management via `memory_limit` and `threads` parameters.
* Added `build_corpus_index()` function for creating memory-efficient Parquet indexes for fast ID lookups.
  Handles 300M+ records by streaming directly to file without loading into R memory.
  For OpenAlex IDs, creates hive-partitioned index by `id_block` for O(1) lookups.
* Added `lookup_by_id()` function for fast record retrieval from a parquet corpus using pre-built indexes.
  Supports both OpenAlex ID (partitioned, O(1) lookup) and DOI lookups with automatic ID normalization.
* Added `snapshot_filter_ids()` function for filtering snapshot data by ID lists.
* Added `id_block()` helper function for computing ID block partitions.

## Documentation

* Added `snapshot.qmd` vignette with comprehensive guide on downloading, converting, and querying
  OpenAlex snapshots locally.

## Changes

* Removed `overwrite` parameter from `snapshot_to_parquet()`. Existing datasets are now skipped
  with a warning message indicating manual removal is required for re-conversion.

## Bug Fixes

* Fixed vignette parse errors in `pro_query.qmd` (malformed code block closings).

## Tests

* Added comprehensive tests for `snapshot_to_parquet()`, `build_corpus_index()`, and `lookup_by_id()`.

# openalexPro v0.4.2

## Breaking Changes

* removal of `load_sql_file()` function as not needed anymore

## Documentation

* Update from vignettes and adding of new ones
* Update of README.md

## Tests

* Remove need in tests for openalexR

# openalexPro 0.4.1

* Standardised progressbar handling
* Changed default pages from 1,000 to 10,000
* Refactored `pro_query` and removed `multiple_ids` argument using Claude and expanded tests and added vignette.
* Added creation of `00_completed` in output directory of `json`, `jsonl` and `parquet` folders upon successful completion
* Changed api key and email handling. Removed oap_mail()_ and oap_apikey() and simplified handling of api key and email to only use
  environmental variables `openalexPro.email` and `openalexPro.apikey`
* Added unified schema inference to `pro_request_jsonl_parquet()` to prevent schema conflicts when reading
  combined Parquet datasets. New `sample_size` parameter controls schema inference sampling. This fixes
  "Unsupported cast from string to struct" errors when fields have different types across JSONL files
  (e.g., `apc_paid` being `null` in some files and a struct in others).
* Removed `harmonize_parquet_schemata()` as it is no longer needed with the new unified schema inference.
* Increased default n umber of pages to be read by `request_json()` from 1000 to 10000 to allow the initially planned 2,000,000
  work download.
  
# openalexPro 0.4.0
* CI and coverage tweaks for CRAN readiness.

* splitting snowball functionality into openalexSnowball

# openalexPro 0.3.1

* Added `pro_fetch()` with `project_folder` support for structured outputs.
* Added progress reporting and parallelization for `pro_request_jsonl()`.
* Added `sample_parquet_n()` random sampling utilities with `select` support.
* Improved `count_only` output to return a data frame with an error column.

# openalexPro 0.3.0

* Added `count_only` support for `pro_request()` and related helpers.
* Added DOI handling improvements and API call fixes.

# openalexPro 0.2.0

* Introduced `pro_query()` as the package-native query builder with chunking.
* Added snowball search utilities and citation edge extraction workflow.
* Expanded conversion pipeline tests and VCR-based API fixtures.
* Added `extract_doi()` helpers and compatibility reporting artifacts.
