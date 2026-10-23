\echo 'Common: completed (900,000 rows)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM payments WHERE status = 'completed';
\echo 'Rare: failed (10,000 rows)'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM payments WHERE status = 'failed';
