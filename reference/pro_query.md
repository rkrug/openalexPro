# Build an OpenAlex request (httr2)

Construct an `httr2` request for the OpenAlex API. All filters must be
supplied as named `...` arguments (e.g.,
`from_publication_date = "2020-01-01"`).

## Usage

``` r
pro_query(
  entity = c("works", "authors", "venues", "institutions", "concepts", "publishers",
    "funders"),
  id = NULL,
  multiple_id = FALSE,
  search = NULL,
  group_by = NULL,
  select = NULL,
  options = NULL,
  endpoint = "https://api.openalex.org",
  mailto = NULL,
  user_agent = NULL,
  chunk_limit = 50L,
  ...
)
```

## Arguments

- entity:

  Character; one of `"works"`, `"authors"`, `"venues"`,
  `"institutions"`, `"concepts"`, `"publishers"`, `"funders"`.

- id:

  Optional single ID (e.g., `"W1775749144"`) to fetch one entity.

- multiple_id:

  Logical; if `TRUE` and `id` is a vector, the IDs are moved into the
  `ids.openalex` filter and `id` is cleared.

- search:

  Optional full-text search string.

- group_by:

  Optional field to group by (facets), e.g. `"type"`.

- select:

  Optional character vector of fields to return.

- options:

  Optional named list of additional query parameters (e.g.,
  `list(per_page = 200, sort = "cited_by_count:desc", cursor = "*", sample = 100)`).

- endpoint:

  Base API URL. Defaults to `"https://api.openalex.org"`.

- mailto:

  Optional email to join the polite pool; added as a query parameter and
  appended to the `User-Agent`.

- user_agent:

  Optional custom `User-Agent`.

- chunk_limit:

  Number of DOIS or ids per chunk if chunked. Default: 50

- ...:

  Filters as named arguments. Values may be scalars or vectors (vectors
  are collapsed with `"|"` to express OR).

## Value

An individual URL or a list of URLs.

## Details

Filter names are validated via `.validate_filter()` using
[`opt_filter_names()`](https://rkrug.github.io/openalexPro/reference/opt_filter_names.md).
`select` fields are validated via `.validate_select()` using
`` `opt_select_fields()` ``.

If multiple more then 50 \`doi\` or openalex \`id\`s are provided, the
request is automatically split into chunks of 50 and a named list of
URLs is returned.

## Examples

``` r
if (FALSE) { # \dontrun{

req <- oa_build_req(
  entity = "works",
  search = "biodiversity",
  from_publication_date = "2020-01-01",
  language = c("en","de"),
  select = c("id","title","publication_year"),
  options = list(per_page = 5),
  mailto = "you@example.org"
)
# resp <- api_call(req)
# httr2::resp_body_json(resp)
} # }
```
