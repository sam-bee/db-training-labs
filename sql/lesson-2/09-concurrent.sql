\ir guard.sql
\echo 'Run outside BEGIN. The rebuild can wait for relevant transactions; ordinary reads/writes can continue.'
REINDEX INDEX CONCURRENTLY public.payments_client_id_idx;
\echo 'Concurrent rebuild complete. Inspect index validity with ./lab locking check after ending A.'
