-- inst/views_json.sql
INSTALL json;
LOAD json;
-- 
-- Create VIEW of results in json files
-- 
CREATE VIEW results AS
SELECT UNNEST(results, max_depth := 2)
FROM read_json_auto('%%JSON_DIR%%/*.json');
-- 
-- Create VIEW to create abstracts
-- 
CREATE VIEW abstracts AS
SELECT id,
    list_aggregate(
        map_keys(abstract_inverted_index),
        'string_agg',
        ' '
    ) as ab
FROM results
GROUP BY id,
    abstract_inverted_index;
--
-- Create VIEW to link abstracts to results
--
CREATE VIEW results_with_abstracts AS
SELECT results.*,
    abstracts.*
FROM results
    LEFT JOIN abstracts ON results.id = abstracts.id;
-- 
-- Create VIEW to create citations
-- 
CREATE VIEW results_with_abstracts_citation AS
SELECT *,
    CASE
        WHEN len(authorships) = 1 THEN authorships [1].author.display_name || ' (' || publication_year || ')'
        WHEN len(authorships) = 2 THEN authorships [1].author.display_name || ' & ' || authorships [2].author.display_name || ' (' || publication_year || ')'
        WHEN len(authorships) > 2 THEN authorships [1].author.display_name || ' et al.' || ' (' || publication_year || ')'
    END AS citation
FROM results_with_abstracts;
-- 
-- 
-- The VIEW named for_parquet is used in the `json_to_parquet()` function
-- 
-- 
CREATE VIEW for_parquet AS
SELECT *
FROM results_with_abstracts_citation;