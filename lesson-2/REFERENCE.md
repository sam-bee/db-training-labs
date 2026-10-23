# Lesson 2 rehearsal observations

Rehearsed on **24 October 2026** using the repository's
`postgres:18.6-bookworm` container (reported PostgreSQL 18.6, Debian
18.6-1.pgdg12+2). These are observations from the automated concurrent-connection
rehearsal, not timing guarantees.

Run `./lab locking verify` to regenerate full evidence in
`results/verify-locking.log`. The verifier creates and drops its own database
and synchronizes on actual lock states rather than assuming a command takes a
particular number of milliseconds. The local rehearsal used DB_PORT=55433
because another service was using 5433; the host bind remained 127.0.0.1.

## Observed outcomes

| Case | Observation |
| --- | --- |
| A updates 902 in an open transaction | A sees 101.00; an ordinary read from another connection sees 100.00 |
| Independent writer | UPDATE of 905 succeeds while A holds 902 |
| Competing writer | UPDATE of 902 waits on A; proceeds after A rolls back |
| FOR UPDATE | Ordinary read continues; competing writer waits |
| Open read transaction and DDL | A holds AccessShareLock; B waits for AccessExclusiveLock on payments |
| Reader after queued DDL | The later reader waits behind B, even though B has not acquired its DDL lock |
| Ordinary REINDEX, explicit transaction retained | A holds ShareLock on payments and AccessExclusiveLock on payments_client_id_idx |
| Fresh read during that ordinary REINDEX transaction | B holds AccessShareLock on payments and waits for AccessShareLock on payments_client_id_idx |
| Writer during ordinary REINDEX transaction | B waits on the table lock, including a write to payment 905 |
| REINDEX CONCURRENTLY with open writer A | B holds ShareUpdateExclusiveLock on payments and relevant indexes and waits for A |
| Concurrent progress | command = REINDEX CONCURRENTLY; phase = waiting for writers before build |
| Other work during that wait | A plain read and an independent-row update both complete |
| After concurrent rebuild | Exactly two indexes remain, both ready and valid; no transient rebuild index remains |
| Lock timeout | B reports SQLSTATE 55P03, rolls back, and A remains idle in transaction |
| Two-row deadlock | PostgreSQL reports 40P01; both connections recover with ROLLBACK |
| Cleanup | Full payment-value fingerprint is unchanged; reset reproduces it |

Ordinary REINDEX locks were deliberately retained with BEGIN until ROLLBACK.
This makes the conflict visible after the small rebuild finishes. It is not a
measurement of a production rebuild's normal duration.

PIDs, transaction IDs, index OIDs, progress phase duration and timings vary.
Inspect the dependency, not an exact numeric value. Row locks are normally
stored on disk; competing row changes often show transaction-ID waits.

## PostgreSQL references

- [Explicit locking](https://www.postgresql.org/docs/18/explicit-locking.html):
  lock compatibility, row locks, transaction lifetime and deadlocks.
- [MVCC](https://www.postgresql.org/docs/18/mvcc-intro.html) and
  [Read Committed](https://www.postgresql.org/docs/18/transaction-iso.html#XACT-READ-COMMITTED):
  committed row versions and concurrent updates.
- [REINDEX](https://www.postgresql.org/docs/18/sql-reindex.html): ordinary
  index-lock/read-planning caveat, concurrent phases and restrictions.
- [ALTER TABLE](https://www.postgresql.org/docs/18/sql-altertable.html):
  lock requirements vary by subcommand; ADD COLUMN in this lesson needs
  ACCESS EXCLUSIVE.
- [pg_locks](https://www.postgresql.org/docs/18/view-pg-locks.html) and
  [blocking PIDs](https://www.postgresql.org/docs/18/functions-info.html#FUNCTIONS-INFO-SESSION):
  held/requested lock modes and dependency chains.
- [Progress reporting](https://www.postgresql.org/docs/18/progress-reporting.html#CREATE-INDEX-PROGRESS-REPORTING):
  reindex progress and writer waits.
- [Client timeouts](https://www.postgresql.org/docs/18/runtime-config-client.html#GUC-LOCK-TIMEOUT):
  lock_timeout versus statement_timeout.
