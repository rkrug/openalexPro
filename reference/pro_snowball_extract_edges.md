# A function to extract the edges from a parquet database containing the nodes

A function to extract the edges from a parquet database containing the
nodes

## Usage

``` r
pro_snowball_extract_edges(
  nodes = NULL,
  output = tempfile(fileext = ".snowball"),
  verbose = FALSE
)
```

## Arguments

- nodes:

  Path to the nodes parquet dataset

- output:

  output folder, in which the parquet database containing the edges
  called `edges` will be savedp default: temporary directory.

- verbose:

  Logical indicating whether to show a verbose information. Defaults to
  `FALSE`

## Value

A list containing 2 elements:

- nodes: dataframe with publication records. The last column `oa_input`
  indicates whether the work was one of the input `identifier`(s).

- edges: publication link dataframe of 2 columns `from, to` such that a
  row `A, B` means A -\> B means A cites B. In bibliometrics, the
  "citation action" comes from A to B.

## Examples

``` r
if (FALSE) { # \dontrun{

snowball_docs <- pro_snowball(
   identifier = c("W2741809807", "W2755950973"),
   citing_params = list(from_publication_date = "2022-01-01"),
   cited_by_params = list(),
   verbose = TRUE
)

# Identical to above, but searches using paper DOIs

snowball_docs_doi <- oa_snowball(
   doi = c("10.1016/j.joi.2017.08.007", "10.7717/peerj.4375"),
   citing_params = list(from_publication_date = "2022-01-01"),
   cited_by_params = list(),
   verbose = TRUE
)
} # }
```
