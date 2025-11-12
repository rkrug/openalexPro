# Read corpus from Parquet Dataset

This function reads a corpus in Apache Parquet format and returns an
`ArrowObject` representing the corpus which can be fed into a `dplyr`
pipeline or a `tibble` which contains all the data.

## Usage

``` r
read_corpus(corpus, return_data = FALSE)
```

## Arguments

- corpus:

  The directory of the Parquet files.

- return_data:

  Logical indicating whether to return an `ArrowObject` representing the
  corpus (default) or a `tibble` containing the whole corpus shou,d be
  returned.

## Value

An `ArrowObject` representing the corpus or a `tibble`.
