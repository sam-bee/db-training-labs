\ir guard.sql
BEGIN;
SELECT id, amount FROM public.payments WHERE id = 902;
\echo 'The SELECT finished; its explicit transaction did not. Run 07-ddl in B, then observe.'
