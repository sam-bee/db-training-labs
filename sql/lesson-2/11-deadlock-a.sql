\ir guard.sql
BEGIN;
UPDATE public.payments SET amount = amount + 1 WHERE id = 902;
\echo 'First run 12-deadlock-b in B. In B, UPDATE payments SET amount = amount + 1 WHERE id = 902;'
\echo 'While B waits, in A: UPDATE payments SET amount = amount + 1 WHERE id = 905;'
\echo 'After deadlock detection, ROLLBACK in BOTH connections. The victim is not predictable.'
