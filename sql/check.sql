\set ON_ERROR_STOP on
\pset pager off
DO $$
BEGIN
    IF (SELECT count(*) FROM public.payments) <> 1000000
       OR (SELECT count(DISTINCT client_id) FROM public.payments) <> 1000
       OR (SELECT count(*) FROM public.payments WHERE client_id = 42) <> 1000
       OR (SELECT count(*) FROM public.payments WHERE status = 'completed') <> 900000
       OR (SELECT count(*) FROM public.payments WHERE status = 'failed') <> 10000
       OR (SELECT count(*) FROM public.payments WHERE status = 'pending') <> 90000
       OR EXISTS (SELECT FROM public.payments
                  WHERE created_at < TIMESTAMPTZ '2026-01-01 00:00:00+00'
                     OR created_at >= TIMESTAMPTZ '2027-01-01 00:00:00+00')
    THEN
        RAISE EXCEPTION 'Seed differs from the lesson dataset. Run ./lab reset to restore it.';
    END IF;
END
$$;
SELECT status, count(*) AS payments,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS percent
FROM public.payments GROUP BY status ORDER BY payments DESC;
SELECT count(*) AS client_42_payments,
       min(created_at) AS earliest, max(created_at) AS latest
FROM public.payments WHERE client_id = 42;
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'payments' ORDER BY indexname;
\echo 'Seed checks passed. Initial state has only payments_pkey; exercises add other indices.'
