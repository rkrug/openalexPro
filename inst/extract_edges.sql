--
-- nodes table or view
-- CREATE VIEW nodes AS SELECT * FROM read_parquet('FOLDER/**/*.parquet');
-- NEEDS TO BE IN THE DATABASE ALREADY
--
CREATE OR REPLACE VIEW keypaper AS
SELECT *
FROM nodes
WHERE relation = 'keypaper';
--
-- all edges, even outgoing ones
--
CREATE OR REPLACE  VIEW edges_basic AS
SELECT DISTINCT *
FROM (
        SELECT id as 'from',
            UNLIST(referenced_works) as 'to'
        FROM nodes
    );
--
-- Create edges view including edge_type
--
CREATE OR REPLACE VIEW edges AS
SELECT edges_basic.*,
    CASE
        WHEN (
            kpfrom.id IS NOT NULL
            OR kpto.id IS NOT NULL
        )
        AND nfrom.id IS NOT NULL
        AND nto.id IS NOT NULL THEN 'core'
        WHEN nfrom.id IS NOT NULL
        AND nto.id IS NOT NULL THEN 'extended'
        ELSE 'outside'
    END AS edge_type
FROM edges_basic
    LEFT JOIN keypaper AS kpfrom ON edges_basic.from = kpfrom.id
    LEFT JOIN keypaper AS kpto ON edges_basic.to = kpto.id
    LEFT JOIN nodes AS nfrom ON edges_basic.from = nfrom.id
    LEFT JOIN nodes AS nto ON edges_basic.to = nto.id