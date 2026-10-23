\set ON_ERROR_STOP on
\pset pager off
\echo 'Resetting only public.payments: replacing its rows and all its indices.'
\timing on
BEGIN;
DROP TABLE IF EXISTS public.payments;
CREATE TABLE public.payments (
    id bigint PRIMARY KEY,
    client_id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    status text NOT NULL CHECK (status IN ('completed', 'failed', 'pending')),
    amount numeric(12, 2) NOT NULL CHECK (amount > 0)
);

-- No random(), clock, or downloaded data. Each of 1,000 clients has 1,000
-- payments; multiplication permutes client IDs through physical row order.
-- Status varies by 1,000-row block, independently of client ID, giving each
-- client 900 completed, 10 failed and 90 pending payments.
-- Dates are spread through 2026, independent of insertion order.
INSERT INTO public.payments (id, client_id, created_at, status, amount)
SELECT n,
       1 + ((n * 37) % 1000)::integer,
       TIMESTAMPTZ '2026-01-01 00:00:00+00'
           + ((n * 104729) % 31536000) * INTERVAL '1 second',
       CASE
           WHEN ((n - 1) / 1000) % 100 < 90 THEN 'completed'
           WHEN ((n - 1) / 1000) % 100 = 90 THEN 'failed'
           ELSE 'pending'
       END,
       ((1 + (n * 97) % 100000)::numeric / 100)::numeric(12, 2)
FROM generate_series(1::bigint, 1000000::bigint) AS seed(n);
COMMIT;

-- VACUUM cannot run in the transaction above. Collect statistics and mark
-- pages visible so the baseline is prepared consistently after every reset.
VACUUM (ANALYZE) public.payments;
\echo 'Ready: 1,000,000 payments; only payments_pkey exists.'
