EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM payments
WHERE client_id = 7
  AND created_at >= DATE '2026-03-01'
  AND created_at <  DATE '2026-04-01'
ORDER BY created_at DESC
LIMIT 20;
