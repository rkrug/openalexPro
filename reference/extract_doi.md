# Extract DOIs or Components from Character Vectors

Extracts DOIs or specific DOI components (resolver, prefix, or suffix)
from a character vector. Assumes that each element of \`x\` contains at
most one DOI (with or without resolver).

## Usage

``` r
extract_doi(
  x,
  non_doi_value = "",
  normalize = TRUE,
  what = c("doi", "resolver", "prefix", "suffix")
)
```

## Arguments

- x:

  A character vector potentially containing DOIs (e.g., raw DOIs, DOI
  URLs, or strings with embedded DOIs).

- non_doi_value:

  Value to use for elements where no DOI or component is found. If
  \`NULL\`, only matched elements are returned.

- normalize:

  Logical. If \`TRUE\` (default), convert extracted DOIs and suffixes to
  lowercase and trim surrounding whitespace. Has no effect for \`what =
  "prefix"\` or \`what = "resolver"\`.

- what:

  What to extract from each element. One of:

  "doi"

  :   The full DOI name (prefix + "/" + suffix). Example:
      \`"10.5281/zenodo.1234567"\` (default)

  "resolver"

  :   The resolver URL (e.g., \`"https://doi.org/"\`,
      \`"http://dx.doi.org/"\`) if present

  "prefix"

  :   The DOI prefix only (e.g., \`"10.5281"\`)

  "suffix"

  :   The DOI suffix only (e.g., \`"zenodo.1234567"\`)

## Value

A character vector: - If \`non_doi_value\` is not \`NULL\`, a vector of
the same length as \`x\`, with unmatched entries replaced. - If
\`non_doi_value\` is \`NULL\`, a vector of only matched entries.

## Examples

``` r
x <- c(
  "https://doi.org/10.5281/zenodo.1234567",
  " 10.1000/XYZ456  ",
  "no doi here",
  NA
)

extract_doi(x)  # Full DOIs (default)
#> [1] "10.5281/zenodo.1234567" "10.1000/xyz456"         ""                      
#> [4] ""                      
extract_doi(x, what = "resolver")
#> [1] "https://doi.org/" ""                 ""                 ""                
extract_doi(x, what = "prefix")
#> [1] "10.5281" "10.1000" ""        ""       
extract_doi(x, what = "suffix")
#> [1] "zenodo.1234567" "xyz456"         ""               ""              
extract_doi(x, non_doi_value = NA_character_)
#> [1] "10.5281/zenodo.1234567" "10.1000/xyz456"         NA                      
#> [4] NA                      
extract_doi(x, non_doi_value = NULL)
#> [1] "10.5281/zenodo.1234567" "10.1000/xyz456"        
```
