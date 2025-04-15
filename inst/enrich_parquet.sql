-- 
-- Create VIEW of results in json files
-- Moved to R code
-- 
-- CREATE VIEW results AS
-- SELECT abstract_inverted_index
-- FROM read_parquet('corpus/**/*.parquet');
-- 
-- Create VIEW to create abstracts
-- 
CREATE VIEW enriched AS
SELECT *,
    -- Expand abstract
    list_aggregate(
        map_keys(abstract_inverted_index),
        'string_agg',
        ' '
    ) as abstract,
    -- Create short citations
    CASE
        WHEN len(authorships) = 1 THEN authorships [1].author.display_name || ' (' || publication_year || ')'
        WHEN len(authorships) = 2 THEN authorships [1].author.display_name || ' & ' || authorships [2].author.display_name || ' (' || publication_year || ')'
        WHEN len(authorships) > 2 THEN authorships [1].author.display_name || ' et al.' || ' (' || publication_year || ')'
    END AS citation
FROM read_parquet('%%parquet_file%%');
-- 
- -