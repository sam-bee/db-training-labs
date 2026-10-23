#!/bin/sh
# Full rehearsal in a new database; the learner's payments database is untouched.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
./lab start
mkdir -p results
log_file="$PWD/results/verify.log"
verify_database="lab_verify_$$"

psql_verify() {
    docker compose exec -T db psql -X -U student -d "$verify_database" \
        -v ON_ERROR_STOP=1 -P pager=off "$@"
}

docker compose exec -T db createdb -U student "$verify_database"
cleanup() {
    verify_status=$?
    trap - 0
    docker compose exec -T db dropdb -U student --force "$verify_database" || true
    if [ "$verify_status" -ne 0 ]; then
        printf 'Verification failed. Recent output from %s:\n' "$log_file" >&2
        tail -60 "$log_file" >&2
    fi
    exit "$verify_status"
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Seeding isolated database %s; plans go to %s\n' "$verify_database" "$log_file"
psql_verify -f /lab/sql/reset.sql >"$log_file" 2>&1
psql_verify -f /lab/sql/check.sql >>"$log_file" 2>&1

# A fingerprint of every value catches accidental data changes and checks that
# reset regenerates the same data. It is not a timing or planner assertion.
fingerprint_sql='SELECT sum(hashtextextended(p::text, 0)::numeric) FROM public.payments AS p'
seed_fingerprint=$(psql_verify -Atqc "$fingerprint_sql")
initial_indices=$(psql_verify -Atqc "SELECT string_agg(indexname, ',' ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='payments'")
[ "$initial_indices" = payments_pkey ]

for exercise in 01-baseline 02-client-index 03-selectivity 04-composite 05-costs 06-review; do
    printf 'Rehearsing %s\n' "$exercise"
    psql_verify -f "/lab/sql/$exercise.sql" >>"$log_file" 2>&1
done
after_fingerprint=$(psql_verify -Atqc "$fingerprint_sql")
[ "$seed_fingerprint" = "$after_fingerprint" ]
final_indices=$(psql_verify -Atqc "SELECT string_agg(indexname, ',' ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='payments'")
[ "$final_indices" = 'payments_client_created_at_idx,payments_client_id_idx,payments_pkey,payments_status_idx' ]

printf 'Checking repeat runs and reset\n'
for exercise in 02-client-index 03-selectivity 04-composite 05-costs; do
    psql_verify -f "/lab/sql/$exercise.sql" >>"$log_file" 2>&1
done
psql_verify -f /lab/sql/reset.sql >>"$log_file" 2>&1
psql_verify -f /lab/sql/check.sql >>"$log_file" 2>&1
reset_fingerprint=$(psql_verify -Atqc "$fingerprint_sql")
[ "$seed_fingerprint" = "$reset_fingerprint" ]
reset_indices=$(psql_verify -Atqc "SELECT string_agg(indexname, ',' ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='payments'")
[ "$reset_indices" = payments_pkey ]
printf 'Passed: all exercises, repeat runs, unchanged seed, deterministic reset, initial/final indices.\n'
