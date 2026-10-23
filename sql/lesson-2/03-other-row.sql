\ir guard.sql
BEGIN;
UPDATE public.payments SET amount = amount + 1 WHERE id = 905 RETURNING id, amount;
ROLLBACK;
\echo 'Payment 905 can change independently in this simple schema. The change was rolled back.'
