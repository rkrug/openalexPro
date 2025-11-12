# Read snowball from Parquet Dataset

This function reads a snowball from Apache Parquet format and returns a
list containing nodes and edges, which can be either Arrow Datasets or
`tibble`s.

## Usage

``` r
read_snowball(
  snowball = NULL,
  edge_type = c("core", "extended", "outside"),
  return_data = FALSE,
  shorten_ids = TRUE
)
```

## Arguments

- snowball:

  The directory of the Parquet files as poppulater by
  [`pro_snowball()`](https://rkrug.github.io/openalexPro/reference/pro_snowball.md).

- edge_type:

  type of the returned edges. Possible values are:

  - **`core`**: only edges from or to the keypapers are selected

  - **`extended`**, only edges between the `nodes` are selected (this
    includes `core` edges)

  - **`outside`**: only edges where either the `from` or the `to` is not
    in `nodes` multiple are allowed.

- return_data:

  Logical indicating whether to return an `ArrowObject` representing the
  corpus (default) or a `tibble` containing the whole corpus shou,d be
  returned.

- shorten_ids:

  If `TRUE` the ids will be shortened, i.e. the part
  `https://openalex.org/` will be removed

## Value

A list containing two elements: nodes and edges, which are either
`ArrowObject` representing the corpus or `tibble`s containing the data.
