---
title: "openalexPro README"
date: today
author: Rainer M Krug
format: gfm
---

# This Package is experimental!

# Use at own risk, but please let me know if things do not work!

## Introduction

This package sopplements [openalexR](https://github.com/openalex/openalexR) by providing a more advanced access to OpenAlex for the power user. `openalexR` does all computations an conversions in memory. This is extremely useful for smaller datasets downloaded from [OpenAlex](https://openalex.org), but not practical for larger corpora which would require too much memory. `openalexPro2` does, in contrast, only processes smaller batches (i.e. the individual pages returned by the OpenAlex API) in memory and utilises other frameworks like [DuckDB](https://duckdb.org) and the parquet file format, part of [Arrow](https://arrow.apache.org) if larger amounts need to be processed. This has the advantage to provide a tool to download several millions or records (in one project I downloaded 5.5. million) which would not be possible using `openalexR`.

`openalexProo2` uses the function `openalexR:oa_query()` to build the query, and uses its own download mechaniism to download the results.

The core idea of this package is, as hinted above, to not load all results in memory and convert them (which causes memory bottlenecks in `oepenalexR` but is very useful for smaller return corpi) but rather save each page returned, including all headers, as individual json files in a directory.

These json files are processed further by additional functions. One can directly process th json functions, or the final parquet dataset for further analysis.

It is planned to build additional acompanying packages using these data structures which provide functions to plot snowball searches, to analyse the corus, etc.

A final aim is to make these acompanying packages compatible to `openalexR` outputs, so that one can easily switch from one to the other if the size of the corpus increases.

## Design Principles

Due to the requirement of `openalexPro2` to handle huge corpi with several millions of works, an efficient storage format needs to be provided as a backend. For download the json files are the easiest to use, but for retrieval other formats are more suitable.

The format which is used in this package is the `parquet` format which is space efficient and in the retrieveal of data (see https://parquet.apache.org/docs/ for a detailed description of the format). It interfaces for example directly with `dplyr`, so that one can do a lot of processing before even collecting the actual data, i.e. enabling processing of larger-then-memory datasets.

In addition, as a link between json files, the parquet dataset, and the retrieval of works from the dataset, the `duckdb` package is used. '[DuckDB](https://duckdb.org) is a fast in-process analytical database' as described by them and it integrates peferfectly with `parquet` and 'json' files as well as the `dplyr` pipelines.

The last wheel in the puzzle is the extraction of the actual references from the returned json files as well as the conversion of the abstracts from the inverted index format returned by OpenAlex and the creation of short citations (Author, et al (2020)). This is done by the tool [jq](https://stedolan.github.io/jq/) in the [`jqr`](https://github.com/rkrug/jqr) package.

## Installation

The "stable" version is available via [r-universe](https://rkrug.r-universe.dev/openalexPro2)

```r
install.packages('openalexPro2', repos = c('https://rkrug.r-universe.dev', 'https://cloud.r-project.org'))
```

The "development" version can be installed from github using

```r
remotes::install_github("rkrug/openalexPro", ref = "openalexPro2")
```

## Basic Workflow for Searches

Depending on the search query, the results are either a single record, grpouped records or a table of records.

This workflow can be stoped at any of the stages, and the json files can be processed using own functions.

### 1. Define query

The query is defined using the function `openalexR:oa_query()`. For details about arguments and how to use it, please see there. For convenience, it is re-published in the `openalexPro2` package.

```r
library(openalexPro2)

res <- oa_query(
  title_and_abstract.search = "biodiversity AND conservation AND IPBES",
  entity = "works"
)
```

### 2. Download `json` files

The returned jsons are saved as jsons on the disk in the folder provided by the argument `output`.
They contain metadata from the request as well as the results.

```r
json_raw <- "./json_raw"
openalexPro2::pro_request(
  query_url = query_url,
  output = json_raw,
  verbose = TRUE,
  json_dir = "json_files"
  )
```

### 3. Process `json` files

The processing of the json files is doing the following:

1. extracting of the results from the raw json
2. extracting of the abstracts from the inverted index format
3. creation of short citations

The results are saved in the folder provided by the argument `output`.

```r
json_extracted <- "./json_extracted"
openalex_jsonl_folder <- openalexPoro2::pro_request_jsonl(
  json_dir = "json_files",
  output = json_extracted,
  verbose = TRUE0
)
```

### 4. Convert to `parquet`

Here the files are converted into a parquet dataset saved as individual `parquet` files in the folder provided by the argument `output`.

```r
parquet <- "./parquet"
openalexPro2::pro_request_jsonl_parquet(
  json_dir = json_extracted,
  output = parquet,
  verbose = TRUE
)
```

## Basic Workflow for Snowball Searches

In addition to "normal" searches, snowball searches are implemented. These are searches based on the cited and citing relationships between works. It starts from some key papers and identifies all papers which are citing tthen or are cited by them.

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

## Read Data

The package provides two convenience function for reading obtained data:

- `**read_corpus()**` which reads the corpus either as a `Dataset` object if `rearn_data = FALSE` or a `data.frame`, i.e. a data table, if `rearn_data = TRUE`.
- `**read_snowball()**` which reads the snowball search. The function returns a `list` which contains to elemends, `nodes` and `edges`. Depending on `return_data` argument these are each a `Dataset` or a `data.frame`. The format resulting from `read_snowball(read_data = TRUE)` is in most practical purposes compatible to the `openalexR` `data.frame` or `tibble` output.

The `Dataset` can be processed further using `dplyr` functions withiut actually reading the data. You can read the data finally with `dplyr::collect()`.
