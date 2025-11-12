# A function to get the nodes for a snowball search

A function to get the nodes for a snowball search

## Usage

``` r
pro_snowball_get_nodes(
  identifier = NULL,
  doi = NULL,
  limit = NULL,
  output = tempfile(fileext = ".snowball"),
  verbose = FALSE
)
```

## Arguments

- identifier:

  Character vector of openalex identifiers.

- doi:

  Character vector of dois.

- limit:

  If `citedOnly` only works cited by the keypaper are retrieved,
  `citingOnly` retrieves only works citing the keypaper. Default: `NULL`
  where all will be retrieved. 'none' is equal to `NULL`

- output:

  parquet dataset; default: temporary directory.

- verbose:

  Logical indicating whether to show a verbose information. Defaults to
  `FALSE`

## Value

Path to the nodes parquet dataset
