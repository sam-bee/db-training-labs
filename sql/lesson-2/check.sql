\ir guard.sql
DO $$
BEGIN
    IF (SELECT count(*) FROM public.payments) <> 20000
       OR (SELECT amount FROM public.payments WHERE id = 902) IS DISTINCT FROM 100.00
       OR (SELECT amount FROM public.payments WHERE id = 905) IS DISTINCT FROM 200.00
       OR EXISTS (SELECT 1 FROM pg_index WHERE indrelid = 'public.payments'::regclass
                  AND (NOT indisvalid OR NOT indisready))
       OR NOT EXISTS (SELECT 1 FROM pg_index WHERE indexrelid =
                      to_regclass('public.payments_client_id_idx') AND indisvalid)
       OR EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'payments'
                  AND column_name = 'lesson_note') THEN
        RAISE EXCEPTION 'Lesson 2 seed or indexes changed. End exercise transactions, then ./lab locking reset.';
    END IF;
END $$;
SELECT current_database(), version();
SELECT id, client_id, status, amount FROM public.payments WHERE id IN (902, 905) ORDER BY id;
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'payments';
