% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/source_to_parquet.R
\name{source_to_parquet}
\alias{source_to_parquet}
\title{Convert JSON files to Apache Parquet files}
\usage{
source_to_parquet(
  source_dir = NULL,
  source_type = "pro_request",
  corpus = tempfile(fileext = ".corpus"),
  citations = FALSE,
  abstracts = FALSE,
  ids = NULL,
  partition = NULL,
  verbose = FALSE
)
}
\arguments{
\item{source_dir}{The directory of JSON files returned from \code{pro_request(..., json_dir = "FOLDER")}.}

\item{source_type}{The type of source files. Possible  values are:
\itemize{
\item \strong{pro_request}: The directory of JSON files returned from \code{pro_request(..., json_dir = "FOLDER")}
\item \strong{snapshot}: The directory of the in parquet converted works in a snapshot.
}}

\item{corpus}{parquet dataset; default: temporary directory.}

\item{citations}{Logical. Indicating whether to include additional \code{citation} field
(e.g. \code{Darwin & Newton (1903)}) in the works. Default: \code{FALSE} which means no \code{citation} field in}

\item{ids}{\code{data.frams} or \code{tibble} with \code{id} column which will be used to filter the works to be converted. Default: \code{NULL}, no filtering.}

\item{partition}{The column which should be used to partition the table. Is only used if \code{ids} is \code{NULL}. Hive partitioning is used.}

\item{verbose}{Logical indicating whether to show a verbose information. Defaults to \code{FALSE}}

\item{abstractes}{Logical. Indicating whether to extract abstract from inverted index into the field called \code{abstract}.
Default: \code{FALSE} which means no additional \code{abstract} field}
}
\value{
The function does not return anything, but it creates a directory with
Apache Parquet files.
}
\description{
The function takes a directory of JSON files as written from a call to \code{pro_request(..., source_dir = "FOLDER")}
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
source_to_parquet(source_dir = "json", source_type = "snapshot", corpus = "arrow")
}
}
