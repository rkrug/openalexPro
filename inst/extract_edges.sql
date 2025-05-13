-- nodes view containing all nodes
CREATE VIEW nodes AS
SELECT *
FROM read_parquet('snowball/nodes/*.parquet');
--
-- nodes cited by the keypapers (outgoing - from: keypaper )
--
CREATE VIEW keypaper AS
SELECT *
FROM nodes
WHERE relation = 'keypaper';
--
-- nodes cited by the keypapers (outgoing - from: keypaper )
--
CREATE VIEW cited AS
SELECT *
FROM nodes
WHERE relation = 'cited';
--
-- nodes citing the target keypapers (incoming - to: keypaper)
--
CREATE VIEW citing AS
SELECT *
FROM nodes
WHERE relation = 'citing';
--
-- all edges, even outgoing ones
--
CREATE VIEW edges_all AS
SELECT DISTINCT *
FROM (
        -- cited by the keypapers (outgoing - from: keypaper )
        SELECT UNLIST(referenced_works) as 'from',
            id as 'to'
        FROM cited
        UNION all
        -- citing the target keypapers (incoming - to: keypaper)
        SELECT id as 'from',
            UNLIST(referenced_works) as 'to'
        FROM citing
    );
--
-- filter only the edges where from and to are in the nodes
--
CREATE VIEW edges_filtered AS
SELECT *
FROM edges_all
WHERE "from" IN (
        SELECT id
        FROM nodes
    )
    AND "to" IN (
        SELECT id
        FROM nodes
    );
--
-- Create final edges view
--
CREATE VIEW edges AS
SELECT e.*,
    CASE
        WHEN kp1.id IS NOT NULL
        OR kp2.id IS NOT NULL THEN 'core'
        ELSE 'extended'
    END AS edge_type
FROM edges_filtered e
    LEFT JOIN keypaper kp1 ON e."from" = kp1.id
    LEFT JOIN keypaper kp2 ON e."to" = kp2.id