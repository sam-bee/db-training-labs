\set ON_ERROR_STOP on
\pset pager off
\echo '06 | Stop and predict before reading the plan: client 7 in March 2026, latest 20.'
\echo 'Check existing indices first. This file adds or removes none.'
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'payments' ORDER BY indexname;
\ir queries/review.sql
\ir queries/review.sql
\ir queries/review.sql
\echo 'What work did your candidate remove? What would change your mind?'
\echo 'For a fresh before/after comparison: ./lab reset, run this, then run 04-composite and repeat.'
