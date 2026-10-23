\ir guard.sql
BEGIN;
UPDATE public.payments SET amount = amount + 10 WHERE id = 902 RETURNING id, amount;
ROLLBACK;
\echo 'The competing update continued when A ended. B also rolled back.'
