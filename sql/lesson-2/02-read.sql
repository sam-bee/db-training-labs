\ir guard.sql
SELECT id, amount FROM public.payments WHERE id = 902;
\echo 'A plain read sees the committed amount (100.00 while A holds its uncommitted update).'
