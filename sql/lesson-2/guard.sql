\set ON_ERROR_STOP on
\pset pager off
DO $$
BEGIN
    IF current_database() <> 'locking'
       AND current_database() NOT LIKE 'locking_verify_%' THEN
        RAISE EXCEPTION 'Lesson 2 requires its own database. Connect with ./lab locking a (or b/observer).';
    END IF;
END $$;
