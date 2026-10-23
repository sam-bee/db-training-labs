\set ON_ERROR_STOP on
\pset pager off
\echo '04 | Stretch: find client 42, then return the latest 20 of 1,000 payments.'
CREATE INDEX IF NOT EXISTS payments_client_id_idx ON payments (client_id);
DROP INDEX IF EXISTS payments_client_created_at_idx;
\echo 'BEFORE composite index | round 1'
\ir queries/latest.sql
\echo 'BEFORE composite index | round 2'
\ir queries/latest.sql
\echo 'BEFORE composite index | round 3'
\ir queries/latest.sql
CREATE INDEX payments_client_created_at_idx ON payments (client_id, created_at);
\echo 'AFTER composite index | round 1'
\ir queries/latest.sql
\echo 'AFTER composite index | round 2'
\ir queries/latest.sql
\echo 'AFTER composite index | round 3'
\ir queries/latest.sql
\echo 'Look for a backward index scan, no separate Sort, and just 20 rows below Limit.'
\echo 'Does the index supply both filtering and ordering? Full rows still come from the table.'
