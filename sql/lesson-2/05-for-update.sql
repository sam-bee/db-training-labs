\ir guard.sql
BEGIN;
SELECT id, amount FROM public.payments WHERE id = 902 FOR UPDATE;
\echo 'A changed no values but holds a row lock. Try 02-read and 04-same-row in B, then ROLLBACK in A.'
