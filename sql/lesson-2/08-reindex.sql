\ir guard.sql
BEGIN;
REINDEX INDEX public.payments_client_id_idx;
\echo 'The rebuild finished; its locks remain until this explicit transaction ends.'
\echo 'Try 02-read and 03-other-row separately in B. Inspect each wait, then ROLLBACK in A.'
