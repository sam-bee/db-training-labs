#!/bin/sh
# Exercise actual concurrent connections, synchronizing on locks rather than build timings.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
./lab start
mkdir -p results
verify_database="locking_verify_$$"
work_dir=$(mktemp -d)
log_file="$PWD/results/verify-locking.log"
a_log="$work_dir/a.log"
b_log="$work_dir/b.log"
: >"$log_file"
a_process=
b_process=
late_process=

psql_verify() {
    verify_application=$1
    shift
    docker compose exec -T -e PGAPPNAME="$verify_application" \
        -e PGOPTIONS='-c statement_timeout=20000' db \
        psql -X -U student -d "$verify_database" -v ON_ERROR_STOP=1 \
        -v VERBOSITY=verbose -P pager=off "$@"
}
query() { psql_verify lesson2-verifier -Atqc "$1"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
cleanup() {
    verify_status=$?
    trap - 0
    docker compose exec -T db dropdb -U student --force --if-exists "$verify_database" >>"$log_file" 2>&1 || true
    for worker in "$a_process" "$b_process" "$late_process"; do
        if [ -n "$worker" ]; then wait "$worker" 2>/dev/null || true; fi
    done
    for session_log in "$a_log" "$b_log"; do
        if [ -f "$session_log" ]; then cat "$session_log" >>"$log_file"; fi
    done
    rm -rf "$work_dir"
    if [ "$verify_status" -ne 0 ]; then tail -100 "$log_file" >&2; fi
    exit "$verify_status"
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM

docker compose exec -T db createdb -U student "$verify_database"
if docker compose exec -T db psql -X -U student -d payments -v ON_ERROR_STOP=1 \
    -f /lab/sql/lesson-2/reset.sql >"$work_dir/guard.log" 2>&1; then
    fail 'Lesson 2 reset must refuse the lesson 1 database'
fi
grep -Fq 'Lesson 2 requires its own database' "$work_dir/guard.log" || fail 'Reset failed for an unexpected reason'
printf 'PASS: Lesson 2 reset refuses the lesson 1 database\n'
psql_verify lesson2-setup -f /lab/sql/lesson-2/reset.sql >>"$log_file" 2>&1
seed_fingerprint=$(query 'SELECT sum(hashtextextended(p::text, 0)::numeric) FROM public.payments p')
query 'SELECT version()' >>"$log_file"

mkfifo "$work_dir/a" "$work_dir/b"
psql_verify lesson2-a <"$work_dir/a" >"$a_log" 2>&1 &
a_process=$!
exec 3>"$work_dir/a"
psql_verify lesson2-b <"$work_dir/b" >"$b_log" 2>&1 &
b_process=$!
exec 4>"$work_dir/b"

send_a() { printf '%s\n' "$@" >&3; }
send_b() { printf '%s\n' "$@" >&4; }
wait_marker() {
    marker_log=$1
    marker_text=$2
    marker_attempt=0
    until grep -Fq "$marker_text" "$marker_log"; do
        marker_attempt=$((marker_attempt + 1))
        [ "$marker_attempt" -lt 100 ] || fail "Timed out waiting for $marker_text"
        sleep 0.1
    done
}
run_a() {
    send_a "\\i /lab/sql/lesson-2/$1.sql" "SELECT '$2';"
    wait_marker "$a_log" "$2"
}
run_b() {
    send_b "\\i /lab/sql/lesson-2/$1.sql" "SELECT '$2';"
    wait_marker "$b_log" "$2"
}
release_a() {
    send_a 'ROLLBACK;' "SELECT '$1';"
    wait_marker "$a_log" "$1"
}
wait_sql() {
    condition=$1
    condition_label=$2
    condition_attempt=0
    until [ "$(query "$condition")" = t ]; do
        condition_attempt=$((condition_attempt + 1))
        [ "$condition_attempt" -lt 60 ] || fail "$condition_label"
        sleep 0.1
    done
}
wait_b_blocked() {
    wait_sql "SELECT EXISTS (SELECT 1 FROM pg_stat_activity b, pg_stat_activity a
        WHERE b.datname=current_database() AND a.datname=current_database()
        AND b.application_name='lesson2-b' AND a.application_name='lesson2-a'
        AND b.wait_event_type='Lock' AND a.pid=ANY(pg_blocking_pids(b.pid)))" \
        'Expected B to wait on A'
}
snapshot() {
    printf '\n%s\n' "$1" >>"$log_file"
    psql_verify lesson2-observer -f /lab/sql/lesson-2/observe.sql >>"$log_file" 2>&1
    printf 'PASS: %s\n' "$1"
}

run_a 01-hold-update a-update-held
run_b 02-read b-plain-read
[ "$(query 'SELECT amount FROM payments WHERE id=902')" = 100.00 ] || fail 'Read saw uncommitted amount'
run_b 03-other-row b-independent-update
send_b '\i /lab/sql/lesson-2/04-same-row.sql' "SELECT 'b-same-row-finished';"
wait_b_blocked
snapshot 'Plain reads and independent writes continue; same-row write waits'
release_a a-update-released
wait_marker "$b_log" b-same-row-finished

run_a 05-for-update a-for-update-held
run_b 02-read b-read-through-for-update
send_b '\i /lab/sql/lesson-2/04-same-row.sql' "SELECT 'b-for-update-finished';"
wait_b_blocked
snapshot 'SELECT FOR UPDATE blocks a competing writer, not an ordinary read'
release_a a-for-update-released
wait_marker "$b_log" b-for-update-finished

run_a 06-hold-read a-read-held
send_b '\i /lab/sql/lesson-2/07-ddl.sql' "SELECT 'b-ddl-finished';"
wait_b_blocked
# A later reader queues behind the waiting DDL. Observe from a fourth connection.
psql_verify lesson2-late-reader -f /lab/sql/lesson-2/02-read.sql >"$work_dir/late.log" 2>&1 &
late_process=$!
wait_sql "SELECT EXISTS (SELECT 1 FROM pg_stat_activity c, pg_stat_activity b
    WHERE c.datname=current_database() AND b.datname=current_database()
    AND c.application_name='lesson2-late-reader' AND b.application_name='lesson2-b'
    AND b.pid=ANY(pg_blocking_pids(c.pid)))" 'Expected later read to queue behind waiting DDL'
snapshot 'Open read transaction blocks DDL; queued DDL holds up a later reader'
release_a a-read-released
wait_marker "$b_log" b-ddl-finished
wait "$late_process"
late_process=

run_a 08-reindex a-reindex-read-held
send_b '\i /lab/sql/lesson-2/02-read.sql' "SELECT 'b-reindex-read-finished';"
wait_b_blocked
wait_sql "SELECT EXISTS (SELECT 1 FROM pg_locks l JOIN pg_stat_activity a USING(pid)
    WHERE a.datname=current_database() AND a.application_name='lesson2-a'
    AND l.relation='payments_client_id_idx'::regclass
    AND l.mode='AccessExclusiveLock' AND l.granted)" 'Missing exclusive index lock'
snapshot 'Ordinary REINDEX blocks a freshly planned SELECT on the index lock'
release_a a-reindex-read-released
wait_marker "$b_log" b-reindex-read-finished

run_a 08-reindex a-reindex-write-held
send_b '\i /lab/sql/lesson-2/03-other-row.sql' "SELECT 'b-reindex-write-finished';"
wait_b_blocked
snapshot 'Ordinary REINDEX blocks writes, even to another payment'
release_a a-reindex-write-released
wait_marker "$b_log" b-reindex-write-finished

run_a 01-hold-update a-concurrent-writer-held
send_b '\i /lab/sql/lesson-2/09-concurrent.sql' "SELECT 'b-concurrent-finished';"
wait_b_blocked
wait_sql "SELECT EXISTS (SELECT 1 FROM pg_stat_progress_create_index
    WHERE datname=current_database() AND command='REINDEX CONCURRENTLY'
    AND phase LIKE 'waiting for writers%')" 'Expected concurrent rebuild writer-wait phase'
wait_sql "SELECT EXISTS (SELECT 1 FROM pg_locks l JOIN pg_stat_activity a USING(pid)
    WHERE a.datname=current_database() AND a.application_name='lesson2-b'
    AND l.relation='payments'::regclass AND l.mode='ShareUpdateExclusiveLock'
    AND l.granted)" 'Missing concurrent rebuild table lock'
psql_verify lesson2-live-reader -f /lab/sql/lesson-2/02-read.sql >>"$log_file" 2>&1
psql_verify lesson2-live-writer -f /lab/sql/lesson-2/03-other-row.sql >>"$log_file" 2>&1
snapshot 'Concurrent REINDEX waits for A while normal reads and independent writes succeed'
release_a a-concurrent-writer-released
wait_marker "$b_log" b-concurrent-finished
[ "$(query "SELECT count(*) FROM pg_index WHERE indrelid='payments'::regclass AND indisvalid AND indisready")" = 2 ] || fail 'Expected two valid indexes'
[ "$(query "SELECT count(*) FROM pg_index WHERE indrelid='payments'::regclass")" = 2 ] || fail 'Concurrent rebuild left an extra index'

run_a 01-hold-update a-timeout-held
run_b 10-timeout b-timeout-recovered
grep -Fq 'observed: 55P03' "$b_log" || fail 'Expected lock_timeout SQLSTATE 55P03'
wait_sql "SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE datname=current_database()
    AND application_name='lesson2-a' AND state='idle in transaction')" 'Timeout unexpectedly ended blocker'
snapshot 'Lock timeout aborts B statement; B recovers and A still holds its transaction'
release_a a-timeout-released

# Either participant may be chosen as the deadlock victim. Keep both psql
# processes alive after the expected error so we can roll back both explicitly.
run_a 11-deadlock-a a-deadlock-first
run_b 12-deadlock-b b-deadlock-first
send_a '\set ON_ERROR_STOP off'
send_b '\set ON_ERROR_STOP off'
send_b 'UPDATE payments SET amount=amount+1 WHERE id=902;'
wait_b_blocked
send_a 'UPDATE payments SET amount=amount+1 WHERE id=905;' "SELECT 'a-deadlock-detected';"
wait_marker "$a_log" a-deadlock-detected
send_a 'ROLLBACK;' '\set ON_ERROR_STOP on' "SELECT 'a-deadlock-clean';"
send_b 'ROLLBACK;' '\set ON_ERROR_STOP on' "SELECT 'b-deadlock-clean';"
wait_marker "$a_log" a-deadlock-clean
wait_marker "$b_log" b-deadlock-clean
if ! grep -q '40P01' "$a_log" && ! grep -q '40P01' "$b_log"; then
    fail 'Expected PostgreSQL deadlock detection (40P01)'
fi
snapshot 'Two-row deadlock detected; both connections recovered'

psql_verify lesson2-check -f /lab/sql/lesson-2/check.sql >>"$log_file" 2>&1
[ "$seed_fingerprint" = "$(query 'SELECT sum(hashtextextended(p::text, 0)::numeric) FROM public.payments p')" ] || fail 'Exercise changed payment data'
psql_verify lesson2-setup -f /lab/sql/lesson-2/reset.sql >>"$log_file" 2>&1
[ "$seed_fingerprint" = "$(query 'SELECT sum(hashtextextended(p::text, 0)::numeric) FROM public.payments p')" ] || fail 'Reset is not deterministic'

send_a '\q'
send_b '\q'
exec 3>&- 4>&-
wait "$a_process"
wait "$b_process"
a_process=
b_process=
printf 'Passed: row/table/index conflicts, queueing, concurrent availability, timeout, deadlock, unchanged data and deterministic reset.\n'
printf 'Evidence: %s\n' "$log_file"
