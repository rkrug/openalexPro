# Fetch and convert OpenAlex data

Convenience wrapper around
[`pro_request`](https://rkrug.github.io/openalexPro/reference/pro_request.md),
[`pro_request_jsonl`](https://rkrug.github.io/openalexPro/reference/pro_request_jsonl.md)
and
[`pro_request_jsonl_parquet`](https://rkrug.github.io/openalexPro/reference/pro_request_jsonl_parquet.md).

## Usage

``` r
pro_fetch(
  query_url,
  pages = 10000,
  project_folder = NULL,
  overwrite = FALSE,
  mailto = Sys.getenv("openalexPro.email"),
  api_key = Sys.getenv("openalexPro.apikey"),
  workers = 1,
  verbose = FALSE,
  progress = TRUE,
  count_only,
  error_log = NULL
)
```

## Arguments

- query_url:

  The URL of the API query or a list of URLs returned from
  [`pro_query()`](https://rkrug.github.io/openalexPro/reference/pro_query.md).

- pages:

  The number of pages to be downloaded. The default is set to 10000,
  which would be 2,000,000 works. It is recommended to not increase it
  beyond 100000 due to server load and to use the snapshot instead. If
  `NULL`, all pages will be downloaded. Default: 100000.

- project_folder:

  Directory where all intermediate (`json`, `jsonl`) and final
  (`parquet`) results are stored. If it does not exist, it is created.
  If `NULL`, a temporary directory is created.

- overwrite:

  Logical. If `TRUE`, `output` will be deleted if it already exists.

- mailto:

  The email address of the user.

- api_key:

  The API key of the user.

- workers:

  Number of parallel workers to use if `query_url` is a list. Defaults
  to 1.

- verbose:

  Logical indicating whether to show verbose messages.

- progress:

  Logical indicating whether to show a progress bar. Default `TRUE`.

- count_only:

  Do not use it here. The function will abort if it set to `TRUE` and
  give a warning if `FALSE`

- error_log:

  location of error log of API calls. (default: `NULL` (none)).

## Value

Invisibly, the normalized path of the `parquet` subfolder inside
`project_folder`, i.e. the value returned by
[`pro_request_jsonl_parquet()`](https://rkrug.github.io/openalexPro/reference/pro_request_jsonl_parquet.md).

## Details

The function

- downloads records from OpenAlex via
  [`pro_request()`](https://rkrug.github.io/openalexPro/reference/pro_request.md)
  into a `"json"` subfolder of `project_folder`,

- converts the JSON files to `jsonl` via
  [`pro_request_jsonl()`](https://rkrug.github.io/openalexPro/reference/pro_request_jsonl.md)
  into a `"jsonl"` subfolder, and

- converts the jsonl files to an Apache Parquet dataset via
  [`pro_request_jsonl_parquet()`](https://rkrug.github.io/openalexPro/reference/pro_request_jsonl_parquet.md)
  into a `"parquet"` subfolder.

This is a high-level helper for the common workflow of going from an
OpenAlex query URL to a local Parquet dataset in a single call. In most
cases, this function should be sufficient, but if more control is
needed, the individual functions have to be called separately.

**This function assumes `count_only == FALSE`**
