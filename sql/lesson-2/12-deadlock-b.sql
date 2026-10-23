\ir guard.sql
BEGIN;
UPDATE public.payments SET amount = amount + 1 WHERE id = 905;
\echo 'Next in B: UPDATE payments SET amount = amount + 1 WHERE id = 902;'
\echo 'While B waits, run A''s second update. Finish with ROLLBACK in BOTH connections.'
