% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/json_to_parquet_duckdb.R
\name{json_to_parquet_duckdb}
\alias{json_to_parquet_duckdb}
\title{Convert JSON files to Apache Parquet files}
\usage{
json_to_parquet_duckdb(
  json_dir = system.file("json_1000", package = "openalexPro"),
  corpus = "corpus",
  partition = "publication_year"
)
}
\arguments{
\item{json_dir}{The directory of JSON files returned from \code{oa_request(..., json_dir = "FOLDER")}.}

\item{corpus}{parquet dataset. If \code{partition} is `NULL', a file, otherwise a directorty.}

\item{partition}{The column which should be used to partition the table. Hive partitioning is used.
Set to NULL to not partition the table.}
}
\value{
The function does not return anything, but it creates a directory with
Apache Parquet files.
}
\description{
The function takes a directory of JSON files as written from a call to \code{oa_request(..., json_dir = "FOLDER")}
and converts it to a Apache Parquet dataset.
}
\details{
The function uses DuckDB to read the JSON files and to create the
Apache Parquet files. The function creates a DuckDB connection in memory and
readsds the JSON files into DuckDB when needed. Then it creates a SQL query to convert the
JSON files to Apache Parquet files and to copy the result to the specified
directory.
}
\examples{
\dontrun{
json_to_parquet(json_dir = "json", corpus = "arrow")
}
}
