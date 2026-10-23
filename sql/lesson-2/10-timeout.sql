\ir guard.sql
BEGIN;
SET LOCAL lock_timeout = '3s';
-- This failure is intentional. Continue only so we can show the error code and recover.
\set ON_ERROR_STOP off
UPDATE public.payments SET amount = amount + 10 WHERE id = 902;
\echo 'Expected SQLSTATE 55P03 while A holds the row; observed:' :SQLSTATE
ROLLBACK;
\set ON_ERROR_STOP on
\echo 'B recovered with ROLLBACK. A still holds its lock until A ends.'
