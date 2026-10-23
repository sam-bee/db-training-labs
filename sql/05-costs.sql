\set ON_ERROR_STOP on
\pset pager off
\echo '05 | Storage: inspect whichever indices you have created so far.'
SELECT pg_size_pretty(pg_table_size('payments')) AS table_including_toast,
       pg_size_pretty(pg_indexes_size('payments')) AS all_indices,
       pg_size_pretty(pg_total_relation_size('payments')) AS total;
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes WHERE relid = 'payments'::regclass ORDER BY indexrelname;

\echo 'Optional write experiment: EXPLAIN ANALYZE really inserts 20,000 rows.'
\echo 'Only disposable TEMP tables are written; ROLLBACK removes them at the end.'
\echo 'Both have the same constraints and primary key; one also has three lesson indices.'
BEGIN;
CREATE TEMP TABLE write_baseline (LIKE payments INCLUDING CONSTRAINTS);
ALTER TABLE write_baseline ADD PRIMARY KEY (id);
CREATE TEMP TABLE write_indexed (LIKE payments INCLUDING CONSTRAINTS);
ALTER TABLE write_indexed ADD PRIMARY KEY (id);
CREATE INDEX ON write_indexed (client_id);
CREATE INDEX ON write_indexed (status);
CREATE INDEX ON write_indexed (client_id, created_at);

\echo 'Round 1 | primary key only'
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO write_baseline SELECT * FROM payments WHERE id <= 20000;
\echo 'Round 1 | primary key plus three secondary indices'
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO write_indexed SELECT * FROM payments WHERE id <= 20000;
TRUNCATE write_baseline, write_indexed;
\echo 'Round 2 | reverse the order: primary key plus three secondary indices'
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO write_indexed SELECT * FROM payments WHERE id <= 20000;
\echo 'Round 2 | primary key only'
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO write_baseline SELECT * FROM payments WHERE id <= 20000;
ROLLBACK;
\echo 'This illustrates index maintenance, not production throughput: TEMP tables do not WAL-log row data.'
\echo 'Source reads, cache state and instrumentation also affect times. payments was not changed.'
