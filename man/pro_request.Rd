% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pro_request.R
\name{pro_request}
\alias{pro_request}
\title{\code{openalexR::oa_request()} with additional argument}
\usage{
pro_request(
  query_url,
  pages = 1000,
  output = NULL,
  overwrite = FALSE,
  mailto = oa_email(),
  api_key = oa_apikey(),
  verbose = FALSE,
  progress = TRUE
)
}
\arguments{
\item{query_url}{The URL of the API query.}

\item{pages}{The number of pages to be downloaded. The default is set to
1000, which would be 2,000,000 works. It is recommended to not increase it
beyond 1000 due to server load and to use the snapshot instead. If \code{NULL},
all pages will be downloaded. Default: 1000.}

\item{output}{directory where the JSON files are saved. Default is a
temporary directory. If \code{NULL}, the return value from call to
\code{openalexR::oa_request()} with all the arguments is returned}

\item{overwrite}{Logical. If \code{TRUE}, \code{output} will be deleted if it already
exists.}

\item{mailto}{The email address of the user. See \code{openalexR::oa_email()}.}

\item{api_key}{The API key of the user. See \code{openalexR::oa_apikey()}.}

\item{verbose}{Logical indicating whether to show verbose messages.}

\item{progress}{Logical default \code{TRUE} indicating whether to show a progress
bar.}
}
\value{
If \code{output} is \code{NULL}, the return value from call to
\code{openalexR::oa_request()}, otherwise the complete path to the expanded and
normalized \code{output}.
}
\description{
This function adds one argument to \code{openalexR::oa_request()}, namely
\code{output}. When specified, all return values from OpenAlex will be saved as
jaon files in that directory and the return value is the directory of the
json files.
}
\details{
For the documentation please see \code{openalexR::oa_request()}
}
