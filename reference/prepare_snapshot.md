# Prepare a directory for OpenAlex snapshot management

Copies the Makefile for snapshot management to the specified directory
and provides instructions for creating and managing OpenAlex snapshots.

## Usage

``` r
prepare_snapshot(path = ".", overwrite = FALSE)
```

## Arguments

- path:

  Character. The directory where the Makefile and documentation should
  be copied. Defaults to the current working directory.

- overwrite:

  Logical. Whether to overwrite existing files. Defaults to FALSE.

## Value

Invisibly returns the path to the created Makefile.

## Details

This function sets up a directory for managing OpenAlex snapshots by:

1.  Copying a Makefile with targets for downloading and converting
    snapshots

2.  Copying documentation about the snapshot process

The Makefile provides the following targets:

- help:

  Show available make targets

- snapshot:

  Download/sync OpenAlex snapshot from S3

- parquet:

  Convert snapshot to parquet format

- parquet_index:

  Build ID indexes for fast lookups

- clean:

  Remove generated directories

## Examples

``` r
if (FALSE) { # \dontrun{
# Prepare current directory
prepare_snapshot()

# Prepare a specific directory
prepare_snapshot("/path/to/openalex-data")
} # }
```
