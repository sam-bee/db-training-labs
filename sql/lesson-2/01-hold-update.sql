\ir guard.sql
BEGIN;
UPDATE public.payments SET amount = amount + 1 WHERE id = 902 RETURNING id, amount;
\echo 'A sees 101.00. Leave this transaction open. Try the B scripts, then ROLLBACK in A.'
