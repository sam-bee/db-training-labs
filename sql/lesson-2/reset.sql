\ir guard.sql
\echo 'Resetting public.payments in the separate lesson 2 database.'
BEGIN;
SET LOCAL lock_timeout = '3s';
DROP TABLE IF EXISTS public.payments;
CREATE TABLE public.payments (
    id bigint PRIMARY KEY,
    client_id integer NOT NULL,
    created_at timestamptz NOT NULL,
    status text NOT NULL CHECK (status IN ('completed', 'failed', 'pending')),
    amount numeric(12, 2) NOT NULL CHECK (amount > 0)
);
INSERT INTO public.payments
SELECT n, CASE WHEN n IN (902, 905) THEN 42 ELSE 1 + (n % 1000)::integer END,
       TIMESTAMPTZ '2026-01-01 00:00:00+00' + n * INTERVAL '1 minute',
       'pending',
       CASE WHEN n = 902 THEN 100.00 WHEN n = 905 THEN 200.00
            ELSE (1 + n % 10000)::numeric / 100 END
FROM generate_series(1::bigint, 20000::bigint) AS seed(n);
CREATE INDEX payments_client_id_idx ON public.payments (client_id);
COMMIT;
VACUUM (ANALYZE) public.payments;
\echo 'Ready: 20,000 payments. Payment 902 = 100.00; payment 905 = 200.00.'
