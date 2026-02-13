# Development Notes — openalexPro

This file records architectural decisions, refactoring rationale, and session-level
development history for the `openalexPro` package. It is aimed at future contributors
(and at Claude Code in future sessions) to understand *why* things are the way they are.

---

## 2026-02-13 — DuckDB temp file IO error fix (TEMP_DIR in Makefile)

**Problem:** During `snapshot_to_parquet()` for the `works` dataset (resume run after
an OOM kill), DuckDB raised:

```
IO Error: Could not read enough bytes from file ".tmp/duckdb_temp_storage_DEFAULT-0.tmp":
  attempted to read 262144 bytes from location 24641536
```

DuckDB spills temporary data to `.tmp/` relative to the working directory by default.
This directory can fill up (or be on a slow/full filesystem) causing the error.

**Fix:** Exposed `temp_directory` via a new `TEMP_DIR` Makefile variable (default
`/tmp`) and passed it to `snapshot_to_parquet()` in the `parquet` target. The
`snapshot_to_parquet()` function already accepted `temp_directory`; only the Makefile
was missing the plumbing.

**Changes:**
- Added `TEMP_DIR=/tmp` variable to `inst/Makefile.snapshot`.
- Added `TEMP_DIR` to `help` output and the command-line override example.
- Passed `temp_directory = "'${TEMP_DIR}'"` to `snapshot_to_parquet()` in the `parquet`
  target.
- Updated `vignettes/snapshot.qmd`: added `TEMP_DIR` to the variables table and added a
  Troubleshooting entry explaining the error and fix.

**Key files:** `inst/Makefile.snapshot`, `vignettes/snapshot.qmd`

---

## 2026-02-13 — Remove `mailto`, require `api_key`

**Motivation:** OpenAlex retired email-based polite-pool access. API keys are now the
only supported authentication mechanism. Silently passing an empty key caused opaque
403 errors.

**Changes:**

- Removed `mailto` parameter from `pro_request()`, `pro_fetch()`, `pro_count()`,
  `pro_validate_credentials()`, and `pro_query()` examples.
- Added upfront `api_key` validation in `pro_request()`, `pro_fetch()`, and
  `pro_count()`: if `Sys.getenv("openalexPro.apikey")` is empty, a clear error is
  thrown with instructions to set the env var.
- Simplified User-Agent from `openalexPro v[VERSION] (mailto:[EMAIL])` to
  `openalexPro/[VERSION]`.
- Removed `mailto` query parameter from `pro_count()` requests.
- Updated all four vignettes (`Quick_Start.qmd`, `pro_request.qmd`, `pro_query.qmd`,
  `Workflow.qmd`) to remove email setup steps.
- Updated all test files (`test-004` through `test-008`, `test-005-pro_fetch_search`,
  `test-006`) to remove `mailto = "test@example.com"` arguments.
- Patched VCR cassettes to remove `mailto=...` from recorded URIs.
- Added a dummy `api_key` fallback in `helper_vcr.R` so VCR-based tests pass without
  a real key set in the environment.

**Key files:** `R/pro_request.R`, `R/pro_fetch.R`, `R/pro_count.R`,
`R/pro_validate_credentials.R`, `tests/testthat/helper_vcr.R`,
`tests/fixtures/vcr/*.yml`

---

## 2026-02-13 — snapshot_to_parquet path fixes and Makefile improvements

**Motivation (path collision bug):** The original code used `basename()` to derive
output parquet filenames from input `.gz` filenames. OpenAlex snapshots use hive
partitioning (e.g. `updated_date=2024-01-01/part_000.gz`), so multiple partitions
contain identically-named files. Using `basename()` caused output collisions.

**Fix:** Replaced `basename()` with relative path computation:

```r
json_dir_norm <- normalizePath(json_dir)
rel_paths <- vapply(gz_files, function(f) {
  substring(normalizePath(f), nchar(json_dir_norm) + 2)
}, character(1), USE.NAMES = FALSE)
```

`nchar(root) + 1` = the path separator position; `+2` = first character of the
relative path. Avoids regex escaping entirely.

**Motivation (hive partition naming in pro_request_jsonl_parquet):** Query result
subfolders (e.g. `Chunk_1`, which may contain spaces) should become proper hive
partition directories (`query=Chunk_1`) in the parquet output for compatibility with
Arrow/DuckDB partition-aware reads.

**Fix in `pro_request_jsonl_parquet.R`:**

```r
if (dirname(f_norm) != input_root) {
  file.path(output, paste0("query=", basename(dirname(f_norm))), fname)
} else {
  file.path(output, fname)
}
```

**Makefile improvements (`inst/Makefile.snapshot`):**
- Added `SAMPLE_SIZE=10000` variable (passed to `snapshot_to_parquet()`).
- Added `cli.progress_handlers_force = "cli"` to the `Rscript` options so progress
  bars render in non-interactive (Makefile) sessions.
- Added `SAMPLE_SIZE` to `help` output and the override example line.

**Key files:** `R/snapshot_to_parquet.R`, `R/pro_request_jsonl_parquet.R`,
`inst/Makefile.snapshot`, `tests/testthat/test-013-snapshot_to_parquet.R`

---

## 2026-02-13 — OOM kill fix for schema inference

**Problem:** Running `snapshot_to_parquet()` on the `works` dataset (largest dataset,
~300 GB) with `SAMPLE_SIZE=1000` caused the R process to be killed (exit code 137 =
OOM) during schema inference. The schema inference DuckDB connection had no memory
limit, while the per-file conversion connections did.

**Fix:** Applied `memory_limit` and `temp_directory` settings to the schema inference
connection in `snapshot_to_parquet()` (same settings already applied to per-file
workers). This enables DuckDB to spill to disk during inference rather than exhausting
RAM.

**Note:** A batch-processing approach for schema inference (processing files in chunks
rather than a single DESCRIBE query) was explored but reverted because it changed
column ordering (DuckDB field order vs. `tapply` alphabetical sort), breaking test
snapshots.

**Key file:** `R/snapshot_to_parquet.R` (Stage 1 connection setup, lines ~153–168)

---

## 2026-02-13 — R CMD CHECK: no visible binding for `id`

**Problem:** `R CMD CHECK` reported: `lookup_by_id: no visible binding for global
variable 'id'` due to `dplyr::filter(id %in% ids)` in `R/lookup_by_id.R`.

**Fix:** Changed to `dplyr::filter(.data$id %in% ids)` and added
`@importFrom rlang .data` to the roxygen docs. The `NAMESPACE` was regenerated via
`devtools::document()`.

**Key file:** `R/lookup_by_id.R`

---

## Earlier (0.5.0) — snapshot_to_parquet major refactor

**Motivation:** The original `snapshot_to_parquet()` loaded all `.gz` files for a
dataset into a single DuckDB query, which caused OOM errors for large datasets. The
refactor converts each `.gz` to one `.parquet` file individually, enabling:

- Parallelisation via `future_lapply()` with one DuckDB connection per worker.
- Per-file resume: already-converted files are skipped on re-run.
- Unified schema: a sample of files is used to infer a consistent schema before
  conversion, preventing type conflicts across parquet files.

**Architecture:**

```
snapshot_to_parquet()         # main loop over datasets
  → infer_json_schema()       # Stage 1: DESCRIBE on sample of files
  → future_lapply(            # Stage 2: parallel conversion
      convert_json_to_parquet() # one DuckDB connection per file
    )
```

Both `infer_json_schema()` and `convert_json_to_parquet()` live in
`R/infer_json_schema.R` (internal, `@noRd`).

**Schema inference detail:** Uses DuckDB's
`DESCRIBE SELECT * FROM read_json_auto([...], union_by_name = true)` on a sample of
files. The resulting columns clause (`{'col': 'TYPE', ...}`) is then passed to
`read_json(..., columns = ...)` for each file, ensuring all output parquets share the
same schema even when individual files have missing columns.

**Special case:** The `works` dataset uses `maximum_object_size=1000000000` because
individual work records can exceed DuckDB's default JSON object size limit.

**Key files:** `R/snapshot_to_parquet.R`, `R/infer_json_schema.R`

---

## Earlier (0.5.0) — build_corpus_index and lookup_by_id

**Motivation:** The OpenAlex snapshot after conversion is ~300 GB of parquet files.
Loading it all into memory to look up specific IDs is not feasible. A dedicated index
(`_id_idx.parquet`) stores only `(id, source_file, row_group)` tuples, enabling fast
seeks.

**Architecture:**

```
build_corpus_index(corpus_dir)
  → scans all parquet files in corpus_dir
  → writes corpus_dir_id_idx.parquet alongside corpus_dir

lookup_by_id(ids, corpus_dir, index_file)
  → filters index for matching IDs
  → reads only the relevant row groups from source parquet files
```

**Key files:** `R/build_corpus_index.R`, `R/lookup_by_id.R`

---

## Earlier (0.4.1) — unified schema inference in pro_request_jsonl_parquet

**Motivation:** When downloading a large query, different JSONL pages can have
different column types (e.g. `apc_paid` is `null` in some pages and a struct in
others). Writing these to separate parquet files and then reading them together via
Arrow causes "Unsupported cast" errors.

**Fix:** Added upfront schema inference (sampling up to `sample_size` files with
`union_by_name = true`) before converting, so all parquet files share the same schema.

---

## Earlier (0.4.1) — api_key / email handling simplification

Removed `oa_mail()` and `oa_apikey()` helper functions. Credentials are now read
exclusively from environment variables:

- `openalexPro.apikey` — API key
- `openalexPro.email` — email (polite pool; later removed entirely in dev version)

---

## Earlier (0.3.x) — pro_fetch convenience wrapper

Added `pro_fetch()` as an all-in-one function that chains:
`pro_request()` → `pro_request_jsonl()` → `pro_request_jsonl_parquet()`

into a single call with a `project_folder` argument. Useful for the common "give me
a parquet dataset for this query" use case.

---

## Earlier (0.2.0) — pro_query builder

Added `pro_query()` as the package-native query builder. Handles:
- Entity selection
- Filter construction
- ID chunking (splitting large ID lists into multiple queries to stay within URL
  length limits)
- Returns a list of URLs when chunking is needed

---

## Design decisions (standing)

### One parquet per gz file
Each `.gz` input file produces exactly one `.parquet` output file, preserving
directory structure. This is intentional: it enables resume, parallelism, and
preserves hive partition directories from the source snapshot.

### No merging of parquet files
Parquet files are left as a dataset directory, not merged. Arrow and DuckDB both
handle multi-file datasets natively and more efficiently than a single large file.

### Workers parameter
All parallel operations use `future_lapply()` with `future::multisession`. The `workers`
parameter consistently controls parallelism. When `workers = NULL` or `workers <= 1`,
sequential processing is used.

### VCR cassettes
Tests use the `vcr` package to record/replay API interactions. Cassettes are stored in
`tests/fixtures/vcr/`. The `api_key` query parameter is filtered (replaced with
`<api-key>`) in both recorded and replayed requests. A dummy key
(`"test-api-key"`) is set in `helper_vcr.R` if no real key is present, so tests pass
in CI without real credentials.
