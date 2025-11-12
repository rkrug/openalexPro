---
title: "openalexPro README"
date: today
author: Rainer M Krug
format: gfm
---
[![name status badge](https://rkrug.r-universe.dev/badges/:name)](https://rkrug.r-universe.dev/)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.17453180.svg)](https://doi.org/10.5281/zenodo.17453180)

[![openalexPro status badge](https://rkrug.r-universe.dev/openalexPro/badges/version)](https://rkrug.r-universe.dev/openalexPro)


# Disclaimer



# LLM Usage Disclosure

Code and documentation in this project have been generated with the assistance of the codex LLM tools in Positron. All content and code is based on conceptuaisayion by the authors and has been thoroughly reviewed and edited by humans afterwards.

# Introduction

This package builds on the package [openalexR](https://github.com/openalex/openalexR) but provides a more advanced approach to retrieve works from OpenAlex. In contrast to `openalexR`, which does all processing and conversions in memory. Doing all processing in memory has advantages for smaller smaller number of records retrieved from [OpenAlex](https://openalex.org), but limits te number of works which can be retrieved due to memory limitations. Even before the limit is reached, the often occurring new allocation of memory slows down the processing.
In a first step, In contrast, `openalexPro` uses a on disc processing approach where the data is processed by number of records returned per call, i.e. a per page processing approach. 

# Design Principles
The retrieval of works and the initial processing / preparation can be split into these three steps:

In a first step (`openalexPro::pro_request()`), each page from the API call is saved into an individual json file as returned by the API. The number of retrieved records is effectively only limited by the space on the drive where the json files are saved. As the complete responses including metadata are saved, one could end here and use custom made code to further process the responses, i.e. ingest it into a database. 

In a second step (`openalexPro::pro_request_jsonl()`), the json files are processed on a per file basis using the `jq` command-line json processor. In this step the abstract text is re-constructed, a citation string for each work is generated, and optionally add a `page` field is added. It writes the resulting json file as a newline-delimited JSON (.jsonl), suitable for further processing using `arrow` or DuckDB.

Int the third (and final) step (`openalexPro::pro_request_jsonl_parquet()`) converts the jsonl files into a parquet database partitioned by `page` using the `duckdb` package. Again, as the processing is done per page as well, the conversion is not limited by memory.


This approach results in a stable pipeline which works for the retrieval of small as well as large to huge corpora. As the processing is done in per page (which have a maximum of 200 works), the scaling should be more or less linear  (in one application, more then 4 million works were retrieved without problems). 

One point which needs to be taken into consideration when retrieving huge corpora, are rate limits by OpenAlex (see [here](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication) and [here](https://help.openalex.org/hc/en-us/articles/24397762024087-Pricing) for further details). 


The final format which is used in this package to save the retrieved data is the `parquet` format which is space efficient and allows on disc processing, therefor there is no need to load the complete data into memory (see [here](https://parquet.apache.org/docs/) for a detailed description of the format as well as the [r-package `arrow`](https://arrow.apache.org/docs/r/)). To use the on disc processing in R, the `arrow` packages interfaces directly with `dplyr`, so that one can do a lot of processing before retrieving the actual data into memory (see the section on [dplyr and arrow](https://r4ds.hadley.nz/arrow.html#using-dplyr-with-arrow) as well more general the [arrow chapter](https://r4ds.hadley.nz/arrow.html) in Hadleys Wickhams [R for Data Science (2e) book]()https://r4ds.hadley.nz).

# Quickstart

## Installation

The latest "stable" version is available via [r-universe](https://rkrug.r-universe.dev/openalexPro)

```r
install.packages('openalexPro', repos = c('https://rkrug.r-universe.dev', 'https://cloud.r-project.org'))
```

The "development" version can be installed from github.
**This is generally not recommended!**
Unless you need bleeding edge functionality and can deal with changing function definitions, or whant to test new functionality, is this not recommended.

```r
remotes::install_github("rkrug/openalexPro", ref = "dev")
```

## Basic Workflow for Searches

First, the package needs to be loaded

```r
library(openalexPro)
```

### 1. Define query (`openalexPro:pro_query()`)

The query is defined using the function `openalexPro:pro_query()`. It follows the logic and arguments of `openalexR::oa_query()`. In addition to `openalexR::oa_query()`, the names of filters as well as fields selected for retrieval are verified before sending them to OpenAlex. 

The supported filter names can be retrieved by running

```r
opt_filter_names()
```

and supported select fields by running

```r
opt_select_fields()
```

This defines a basic query.

```r
query <- pro_query(
  title_and_abstract.search = "biodiversity AND conservation AND IPBES",
  entity = "works"
)
```

This returns a URL, which one can open in the browser.

If, however, for example 100 DOIs are given to be retrieved, the query is chunked into chunks of a maximum of the value of the argument `chunk_limit`, default is 50. In this case, the functions returns a `list()` with each element named `Chunk_x` and containing the URL as a character vector.

### 2. Retrieving records (`openalexPro::pro_request()`)

```r
openalexPro::pro_request(
  query_url = query,
  output = "json",
  verbose = TRUE
)
```

Will retrieve the records and save them into the folder specified in output. One important difference is now between the query being a single URL or a list: if it is a list, the `future` and `future.apply` packages are used to process the URLs in the list in parallel.

### 3. Processing `json` files (`openalexPro::pro_request_jsonl()`)

This step prepares the json files for the final ingestion into a `parquet` database:

```r
openalex_jsonl_folder <- openalexPoro2::pro_request_jsonl(
  input_json = "json_files",
  output = json_extracted,
  verbose = TRUE
)
```

The resulting json files can be found in the folder as specified in `output`.

### 4. Convert to `parquet` database (`openalexPro::pro_request_jsonl_parquet()`)

Here the files are converted into a parquet page partitioned dataset saved as individual `parquet` files in the folder provided by the `output` argument.

```r
parquet <- "./parquet"
openalexPro::pro_request_jsonl_parquet(
  json_dir = json_extracted,
  output = parquet,
  verbose = TRUE
)
```

### Convenience Function to Read the Retrieved Data (`openalexPro::read_corpus()`)
The `read_corpus()` function reads the corpus either as a arrow `Dataset` object if `return_data = FALSE`, which is essentially metadata to the dataset,  or a `data.frame`, i.e. a data table, if `return_data = TRUE`, in which case the whole dataset is loaded into memory.


## Basic Workflow for Snowball Searches

As the function `openalexR::oa_snowball()`, `openalexPro` provides a snowball function which stores the results again in a parquet database, but which can be red in a compatible firmat as in `openalexR::oa_snowball()`.

Snowball searches based on following the citation graph and identify the cited and citing works, starting from a set of key-works.

### 1. Define Keypapers

The keypapers can be identified by either their DOIs or their OpenAlex ids.

### 2. Do the snowball search

The snowball search creates several sub-folders in the `output` folder (assumed it is called `snowball`):

```
snowball/
├── cited_json/
├── cited_jsonl/
├── citing_json/
├── citing_jsonl/
├── edges/
├── keypaper_json/
├── keypaper_jsonl/
├── keypaper_parquet/
└── nodes/
```

These contain the following files:

- **raw `json` files returned** (`cited_json`, `citing_json`, `keypaper_json`),
- **processsed `json` files** (`cited_jsonl`, `citing_jsonl`, `keypaper_jsonl`),
- **`parquet` database of the keypaper** (`keypaper_parquet`) and the
- **`nodes` and `edges`** of the snowball search as `parquet` databases.

#### Use OpenAlex ids

```r
snowball_dir <- "./snowball_ids"
snowball_docs <- pro_snowball(
  identifier = c("W2741809807", "W2755950973"),
  output = snowball_dir,
  verbose = TRUE
)
```

#### Use DOIs

```r
snowball_dir_dois <- "./snowball_dois"
oa_snowball(
  doi = c("10.1016/j.joi.2017.08.007", "10.7717/peerj.4375"),
  output = snowball_dir_dois,
  verbose = TRUE
)
```

### Convenience Function to Read the Retrieved Data (`openalexPro::read_snowball()`)


The function `read_snowball()` reads the snowball search. The function returns, if `return_data = TRUE` either a `list` which contains an list two elements, `nodes` and `edges`. This structure of this list is functional identical to the one returned by `openalexR::oa_snowball()` in regards to network structure. If `return_data = FALSE` it returns a `dataset` object 

