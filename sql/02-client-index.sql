\set ON_ERROR_STOP on
\pset pager off
\echo '02 | Predict the plan change before running this file.'
\echo 'First save a baseline with 01-baseline. Add the candidate once:'
CREATE INDEX IF NOT EXISTS payments_client_id_idx ON payments (client_id);
\echo 'Same SELECT, measured run 1'
\ir queries/client.sql
\echo 'Measured run 2'
\ir queries/client.sql
\echo 'Measured run 3'
\ir queries/client.sql
\echo 'An Index Scan or Bitmap Heap/Index Scan uses the index. The planner decides.'
\echo 'Compare work as well as timings. Index creation may have warmed the cache.'
