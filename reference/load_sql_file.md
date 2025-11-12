# Load a SQL file

Load a SQL file, remove all comments starting with "–" and return the
SQL as a single string.

## Usage

``` r
load_sql_file(sql_file = NULL)
```

## Arguments

- sql_file:

  The path to the SQL file.

## Value

A string containing the SQL code which c an be executed in e.g.
\`DBI::dbExecute(conn, sql)\`
