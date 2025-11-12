# Get the OpenAlex API key for requests

Retrieves the API key used for OpenAlex requests. The value is taken
from the environment variable `openalexR.apikey` if set; otherwise it
falls back to the R option `openalexR.apikey`. If neither is defined,
`NULL` is returned.

## Usage

``` r
oap_apikey()
```

## Value

A character scalar with the API key, or `NULL` if not configured.

## Details

This helper mirrors the behavior of
[`openalexR::oa_apikey()`](https://docs.ropensci.org/openalexR/reference/oa_apikey.html)
to make it easy to configure credentials without a hard dependency.
Prefer setting the environment variable for non-interactive usage.

## See also

openalexR::oa_apikey

## Examples

``` r
# Set via environment (preferred in non-interactive contexts)
Sys.setenv(openalexR.apikey = "<api-key>")
oap_apikey()
#> [1] "<api-key>"

# Or via options
options(openalexR.apikey = "<api-key>")
oap_apikey()
#> [1] "<api-key>"
```
