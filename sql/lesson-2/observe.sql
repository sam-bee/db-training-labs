\ir guard.sql
\echo 'Connections: active + Lock means waiting; idle in transaction can be the blocker.'
SELECT pid, application_name, state, xact_start,
       wait_event_type, wait_event, pg_blocking_pids(pid) AS blocking_pids, query
FROM pg_stat_activity
WHERE datname = current_database()
  AND application_name LIKE 'lesson2-%'
  AND pid <> pg_backend_pid()
ORDER BY application_name, pid;

\echo 'Locks: granted=false is a request still waiting. Row conflicts often show transactionid waits.'
SELECT a.application_name, l.pid, l.locktype, l.relation::regclass AS relation,
       l.transactionid, l.mode, l.granted
FROM pg_locks l JOIN pg_stat_activity a USING (pid)
WHERE a.datname = current_database()
  AND a.application_name LIKE 'lesson2-%' AND l.pid <> pg_backend_pid()
ORDER BY a.application_name, l.granted, l.locktype, l.relation;

\echo 'Index progress: REINDEX uses this view too. A small build may finish between observations.'
SELECT pid, command, phase, index_relid::regclass AS index,
       lockers_total, lockers_done, current_locker_pid
FROM pg_stat_progress_create_index
WHERE datname = current_database();
