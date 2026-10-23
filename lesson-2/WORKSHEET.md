# Lesson 2: which operations make other work wait?

**Draft lesson · PostgreSQL 18.6 · about one hour.** Predict → run → inspect →
explain. Focus on which requests conflict, not on memorising lock names.

## Start and open three connections

Run these from the lab repository in a shell:

~~~sh
./lab start
./lab locking reset
./lab locking check
~~~

Lesson 2 uses a separate database, `locking`, with 20,000 deterministic payments
and an index on `client_id`. It does not change lesson 1's `payments` database.
Payment 902 starts at 100.00; payment 905 starts at 200.00. Both belong to client
42. The extra rows give the index some data; this is a concurrency experiment,
not a performance benchmark.

Open three terminal windows and leave each psql prompt running:

| Terminal | Shell command | Connection name |
| --- | --- | --- |
| A | `./lab locking a` | `lesson2-a` |
| B | `./lab locking b` | `lesson2-b` |
| C | `./lab locking observer` | `lesson2-observer` |

The commands below beginning with `\i` run **at the psql prompt**. They load SQL
into that same connection. Some deliberately leave a transaction open; running
the same file in a new one-shot connection would release its locks on exit.
Commands beginning with `./lab` run in your shell, not in psql.

In C, rerun this whenever an operation waits:

~~~sql
\i /lab/sql/lesson-2/observe.sql
~~~

Or use `./lab locking observe` from an additional shell. The observer reports
activity, locks, and reindex progress. Keep C in autocommit mode.

Before each experiment, finish the previous transaction in A and B. All exercise
changes are rolled back. To interrupt a waiting query, press Ctrl+C, then issue
`ROLLBACK;` in that connection. End the blocker's transaction too.

## 1. Read, change another row, change the same row (12–27 minutes)

Predict each outcome before running it:

| A holds an uncommitted update to 902; B tries… | Prediction | Observation / explanation |
| --- | --- | --- |
| Plain read of 902 | | |
| Update of 905 | | |
| Update of 902 | | |

In A:

~~~sql
\i /lab/sql/lesson-2/01-hold-update.sql
~~~

A sees 101.00. Leave it open. In B, run these **one at a time**:

~~~sql
\i /lab/sql/lesson-2/02-read.sql
\i /lab/sql/lesson-2/03-other-row.sql
\i /lab/sql/lesson-2/04-same-row.sql
~~~

The last command should wait. While B waits, inspect from C. Record B's
`wait_event_type`, `wait_event`, and `blocking_pids`. Find that PID in the
activity rows. Is its state `active` or `idle in transaction`?

In A:

~~~sql
ROLLBACK;
~~~

B should continue and roll back its own update. What ended the wait?

<details>
<summary>Expected observations</summary>

The plain read returns committed amount 100.00. A's 101.00 is uncommitted.
Updating 905 can continue and is rolled back by its script. Updating 902 waits
until A ends. Two writers can hold compatible ROW EXCLUSIVE table locks; their
conflict here is the same row. A row conflict commonly appears as a
transaction-ID wait in pg_locks.

</details>

Now repeat with A taking a row lock **without changing the amount**:

~~~sql
-- A
\i /lab/sql/lesson-2/05-for-update.sql
-- B, one at a time
\i /lab/sql/lesson-2/02-read.sql
\i /lab/sql/lesson-2/04-same-row.sql
~~~

Observe, then `ROLLBACK;` in A. Explain why a SELECT can block a writer when it
includes `FOR UPDATE`, while an ordinary SELECT still returns.

## 2. A completed read holds up DDL (27–37 minutes)

In A:

~~~sql
\i /lab/sql/lesson-2/06-hold-read.sql
~~~

The SELECT finished. Has the transaction ended? In B:

~~~sql
\i /lab/sql/lesson-2/07-ddl.sql
~~~

Inspect from C. Compare A's granted `AccessShareLock` on payments with B's
waiting `AccessExclusiveLock`. In A, `ROLLBACK;`. B finishes the schema change,
then rolls it back, removing the added column.

Explain why a nullable column addition that does not rewrite the table can
still wait for a long time.

**Optional queue experiment:** while B's DDL waits, open a fourth terminal with
`./lab locking observer` and run `02-read.sql`. That later reader can queue
behind B. Keep C free to inspect the chain. Release A; B and the later reader
then continue. A waiting lock request can hold up later work too.

## 3. Compare REINDEX modes (37–52 minutes)

### Ordinary rebuild: inspect the retained locks

In A:

~~~sql
\i /lab/sql/lesson-2/08-reindex.sql
~~~

The index rebuild finishes, but the script deliberately keeps its explicit
transaction open. This extends lock lifetime for observation; it does not
measure the natural rebuild duration.

In B:

~~~sql
\i /lab/sql/lesson-2/02-read.sql
~~~

Inspect from C: B's freshly planned read waits on the index's exclusive lock.
End A with `ROLLBACK;` so B continues.

Repeat `08-reindex.sql` in A. This time run the independent-row writer in B:

~~~sql
\i /lab/sql/lesson-2/03-other-row.sql
~~~

Inspect the table lock conflict, then `ROLLBACK;` in A. B completes and rolls
back its change.

**Explain:** ordinary REINDEX takes a write-blocking table lock and an exclusive
index lock. Query planning normally locks every index of a table, so even a
read expected to scan the table can wait. Do not assume “reads are unaffected”.

### Concurrent rebuild: the rebuild itself waits

End any remaining transaction in A and B before this comparison. In A:

~~~sql
\i /lab/sql/lesson-2/01-hold-update.sql
~~~

In B, **outside BEGIN**:

~~~sql
\i /lab/sql/lesson-2/09-concurrent.sql
~~~

While B waits, in C:

~~~sql
\i /lab/sql/lesson-2/observe.sql
\i /lab/sql/lesson-2/02-read.sql
\i /lab/sql/lesson-2/03-other-row.sql
~~~

Record the reindex `phase` and `current_locker_pid`. Can C read payment 902?
Can it change 905? A change to 902 would still wait for A's row lock.

In A, `ROLLBACK;`. Let B finish. From a shell:

~~~sh
./lab locking check
~~~

The replacement index should be valid and no extra rebuild index should remain.

**Explain:** CONCURRENTLY permits normal reads/writes and still holds compatible
maintenance locks. It can itself wait for relevant transactions, does more work,
needs additional space, and can affect latency through resource use. It cannot
run inside an explicit transaction block. A failed or cancelled concurrent
rebuild can leave an invalid index: inspect it before cleanup. For this
disposable lab, finish all transactions and reset to restore a known state.

## 4. Bound the wait and recover (52–57 minutes)

In A, run `01-hold-update.sql` again. In B:

~~~sql
\i /lab/sql/lesson-2/10-timeout.sql
~~~

Wait about three seconds. The script deliberately reports the lock timeout
(SQLSTATE 55P03), then rolls back B's failed transaction. Inspect from C:
did the timeout end A's transaction? Finish with `ROLLBACK;` in A.

`lock_timeout` applies separately to each lock acquisition attempt;
`statement_timeout` limits the overall statement. Cancelling or timing out the
waiter does not end the blocker. Inside an explicit transaction, recover with
ROLLBACK before doing more work.

## 5. Optional deadlock extension

Skip this if the core comparisons need more discussion. Keep a connection open
in A and B, and follow the order exactly:

1. A: `\i /lab/sql/lesson-2/11-deadlock-a.sql` — holds 902.
2. B: `\i /lab/sql/lesson-2/12-deadlock-b.sql` — holds 905.
3. B: `UPDATE payments SET amount = amount + 1 WHERE id = 902;` — waits.
4. A: `UPDATE payments SET amount = amount + 1 WHERE id = 905;` — completes the circle.
5. PostgreSQL detects the deadlock (40P01) and aborts one transaction.
6. Issue `ROLLBACK;` in **both** connections.

The victim is not predictable. Explain why acquiring rows in a consistent order
avoids this pattern, and why an application retries the whole transaction when
appropriate rather than just the failed statement.

## Exit check (57–60 minutes)

- Why can a read return while a write to the same row waits?
- How can a finished read hold up a schema change?
- What does CONCURRENTLY change, and which waits can still happen?
- Which connection must finish to release this observed dependency?

At a shell, run `./lab locking check` after ending all transactions. Type `\q`
to leave each psql connection. For a repeat, `./lab locking reset` restores the
same lesson 2 rows and indexes without changing lesson 1.

## Rehearsal and references

Run `./lab locking verify` to exercise all cases automatically in an isolated
temporary database. It checks actual blocking PIDs and lock modes, successful
reads/writes during concurrent reindexing, timeout/deadlock error codes, index
validity, unchanged payment values, and deterministic reset. It drops its database
on exit. Evidence goes to ignored `results/verify-locking.log`.

See [recorded observations](REFERENCE.md) for the rehearsed outcomes and
PostgreSQL references. Neither slide controls nor the browser execute SQL.
