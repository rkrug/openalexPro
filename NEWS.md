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
