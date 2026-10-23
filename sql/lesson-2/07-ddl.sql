\ir guard.sql
BEGIN;
ALTER TABLE public.payments ADD COLUMN lesson_note text;
ROLLBACK;
\echo 'The DDL acquired its lock after A ended. ROLLBACK removed the added column.'
