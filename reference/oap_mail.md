# Get the contact email for OpenAlex requests

Retrieves the contact email address used in the User-Agent header for
OpenAlex requests. The value is taken from the environment variable
`openalexR.mailto` if set; otherwise it falls back to the R option
`openalexR.mailto`. If neither is defined, `NULL` is returned.

## Usage

``` r
oap_mail()
```

## Value

A character scalar with the email address, or `NULL` if not configured.

## Details

This helper mirrors the behavior of
[`openalexR::oa_email()`](https://docs.ropensci.org/openalexR/reference/oa_email.html)
to make it easy to configure a contact address without a hard
dependency. Supplying a valid email helps with responsible API usage.

## See also

openalexR::oa_email

## Examples

``` r
Sys.setenv(openalexR.mailto = "name@example.org")
oap_mail()
#> [1] "name@example.org"

options(openalexR.mailto = "name@example.org")
oap_mail()
#> [1] "name@example.org"
```
