-- 
INSTALL json;
LOAD json;
-- 
-- Create VIEW keypaper
-- 
CREATE VIEW keypaper AS
SELECT UNNEST(results, max_depth := 2),
    TRUE AS oa_input,
    'keypaper' AS relation
FROM read_json_auto('%%KEYPAPERS_JSON_DIR%%/*.json');
-- 
-- Create VIEW cited
--
CREATE VIEW cited AS
SELECT UNNEST(results, max_depth := 2),
    FALSE AS oa_input,
    'cited' AS relation
FROM read_json_auto('%%CITED_JSON_DIR%%/*.json');
-- 
-- Create VIEW citing
--
CREATE VIEW citing AS
SELECT UNNEST(results, max_depth := 2),
    FALSE AS oa_input,
    'citing' AS relation
FROM read_json_auto('%%CITING_JSON_DIR%%/*.json');
-- 
-- Create VIEW all_nodes
-- 
CREATE VIEW all_nodes AS
SELECT DISTINCT *
FROM (
        SELECT UNNEST(results, max_depth := 2)
        FROM read_json_auto(
                [
        '%%KEYPAPERS_JSON_DIR%%/*.json',
        '%%CITED_JSON_DIR%%/*.json',
        '%%CITING_JSON_DIR%%/*.json'
    ]
            )
    );
-- 
-- Create VIEW info
-- 
CREATE VIEW info AS
SELECT DISTINCT *
FROM (
        SELECT id,
            oa_input,
            relation
        FROM keypaper
        UNION ALL
        SELECT id,
            oa_input,
            relation
        FROM citing
        UNION ALL
        SELECT id,
            oa_input,
            relation
        FROM cited
    );
-- 
-- Create VIEW nodes
-- 
CREATE VIEW nodes AS
SELECT all_nodes.*,
    info.oa_input,
    info.relation
FROM all_nodes
    LEFT JOIN info ON all_nodes.id = info.id;
-- 
-- Create VIEW edges_all
-- 
CREATE VIEW edges_all AS
SELECT DISTINCT *
FROM (
        -- cited from cited 
        SELECT id as 'from',
            UNLIST(referenced_works) as 'to'
        FROM cited
        UNION all
        -- cited from keypaper
        SELECT id AS 'from',
            UNLIST(referenced_works) AS 'to'
        FROM keypaper
        UNION all
        -- cited from citing 
        SELECT id as 'from',
            UNLIST(referenced_works) as 'to'
        FROM citing
    );
-- 
-- Create VIEW edges
-- 
CREATE VIEW edges AS
SELECT *,
    CASE
        WHEN (
            "from" IN (
                SELECT id
                FROM keypaper
            )
        ) THEN 'keypaper'
        WHEN (
            "from" IN (
                SELECT id
                FROM nodes
            )
        ) THEN 'nodes'
        ELSE 'oa'
    END AS from_source,
    CASE
        WHEN (
            "to" IN (
                SELECT id
                FROM keypaper
            )
        ) THEN 'keypaper'
        WHEN (
            "to" IN (
                SELECT id
                FROM nodes
            )
        ) THEN 'nodes'
        ELSE 'oa'
    END AS to_source
FROM edges_all;
-- 
-- Create VIEW snowball
-- 
-- CREATE VIEW snowball AS
-- SELECT struct_pack(row(nodes.*)) AS nodes,
--     struct_pack(row(edges.*)) AS edges,
--     FROM nodes,
--     edges;