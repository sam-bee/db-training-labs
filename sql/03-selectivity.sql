\set ON_ERROR_STOP on
\pset pager off
\echo '03 | Predict separately for completed (90%) and failed (1%).'
\echo 'Remove only the status candidate so this experiment can be repeated.'
DROP INDEX IF EXISTS payments_status_idx;
\echo 'BEFORE status index | round 1'
\ir queries/status.sql
\echo 'BEFORE status index | round 2'
\ir queries/status.sql
\echo 'BEFORE status index | round 3'
\ir queries/status.sql
CREATE INDEX payments_status_idx ON payments (status);
\echo 'AFTER status index | round 1'
\ir queries/status.sql
\echo 'AFTER status index | round 2'
\ir queries/status.sql
\echo 'AFTER status index | round 3'
\ir queries/status.sql
\echo 'Why might the common value still scan the table? Is the index useful for failed?'
\echo 'Do not replace SELECT * with count(*): that would test a different workload.'
