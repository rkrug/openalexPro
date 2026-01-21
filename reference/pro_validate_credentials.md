# Validate OpenAlex credentials

Makes a minimal API request to verify that the api_key is valid.

## Usage

``` r
pro_validate_credentials(
  mailto = Sys.getenv("openalexPro.email"),
  api_key = Sys.getenv("openalexPro.apikey"),
  show_credentials = FALSE
)
```

## Arguments

- mailto:

  Email for polite pool (not validated by API)

- api_key:

  API key to validate

- show_credentials:

  shows the api_key using \`message()\`. USE WITH CAUTION!

## Value

TRUE if credentials work, FALSE otherwise
