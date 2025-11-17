# `openalexR::oa_request()` with additional argument

This function adds one argument to
[`openalexR::oa_request()`](https://docs.ropensci.org/openalexR/reference/oa_request.html),
namely `output`. When specified, all return values from OpenAlex will be
saved as jaon files in that directory and the return value is the
directory of the json files.

## Usage

``` r
pro_request(
  query_url,
  pages = 1000,
  output = NULL,
  overwrite = FALSE,
  mailto = oap_mail(),
  api_key = oap_apikey,
  workers = 1,
  verbose = FALSE,
  progress = TRUE,
  count_only = FALSE,
  error_log = NULL
)
```

## Arguments

- query_url:

  The URL of the API query or a list of URLs returned from
  [`pro_query()`](https://rkrug.github.io/openalexPro/reference/pro_query.md).

- pages:

  The number of pages to be downloaded. The default is set to 1000,
  which would be 2,000,000 works. It is recommended to not increase it
  beyond 1000 due to server load and to use the snapshot instead. If
  `NULL`, all pages will be downloaded. Default: 1000.

- output:

  directory where the JSON files are saved. Default is a temporary
  directory. If `NULL`, the return value from call to
  [`openalexR::oa_request()`](https://docs.ropensci.org/openalexR/reference/oa_request.html)
  with all the arguments is returned

- overwrite:

  Logical. If `TRUE`, `output` will be deleted if it already exists.

- mailto:

  The email address of the user. See
  [`oap_mail()`](https://rkrug.github.io/openalexPro/reference/oap_mail.md).

- api_key:

  The API key of the user. See
  [`oap_apikey()`](https://rkrug.github.io/openalexPro/reference/oap_apikey.md).

- workers:

  Number of parallel workers to use if `query_url` is a list. Defaults
  to 1.

- verbose:

  Logical indicating whether to show verbose messages.

- progress:

  Logical default `TRUE` indicating whether to show a progress bar.

- count_only:

  return count only as a named numeric vector or list.

- error_log:

  location of error log of API calls. (default: `NULL` (none)).

## Value

If `count_only` is `FALSE` (the default) the complete path to the
expanded and normalized `output`. If `count_only` is `TRUE`, a named
numeric vector with the count of the works from the specified
query_url(s).

## Details

For the documentation please see
[`openalexR::oa_request()`](https://docs.ropensci.org/openalexR/reference/oa_request.html)
If query_url is a list, the function is called for each element of the
list in parallel using a maximum of `workers` parallel R sessions. The
results from the individual URLs in the list are returned in a folder
named after the names of the list elements in the `output` folder.
