# A function to perform a snowball search and convert the result to a tibble/data frame.

A function to perform a snowball search and convert the result to a
tibble/data frame.

## Usage

``` r
pro_snowball(
  identifier = NULL,
  doi = NULL,
  output = tempfile(fileext = ".snowball"),
  verbose = FALSE
)
```

## Arguments

- identifier:

  Character vector of openalex identifiers.

- doi:

  Character vector of dois.

- output:

  parquet dataset; default: temporary directory.

- verbose:

  Logical indicating whether to show a verbose information. Defaults to
  `FALSE`

## Value

The folder of the results containing multiple subfolders.
