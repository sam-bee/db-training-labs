\set ON_ERROR_STOP on
\pset pager off
\echo '01 | Predict: how many rows must PostgreSQL examine to find client 42?'
\echo 'Start after ./lab reset; this file does not remove existing indices.'
\d payments
SELECT * FROM payments ORDER BY id LIMIT 6;
SELECT count(*) AS matching_rows FROM payments WHERE client_id = 42;
\echo 'Plan only: cost and rows are estimates; cost is not milliseconds.'
EXPLAIN SELECT * FROM payments WHERE client_id = 42;
\echo 'Measured run 1: ANALYZE executes the SELECT, returning its plan instead of rows.'
\ir queries/client.sql
\echo 'Measured run 2'
\ir queries/client.sql
\echo 'Measured run 3'
\ir queries/client.sql
\echo 'Record scan, filter, estimated/actual output rows, buffers, and execution times.'
\echo 'Which index would you propose? Why would it reduce work?'
