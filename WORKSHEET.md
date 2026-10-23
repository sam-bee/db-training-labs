# Lesson 1 worksheet

Use **predict → run → inspect → explain**. Start setup before the teaching hour.
Follow the [installation steps](README.md), then use the commands below. SQL is in
[`sql/`](sql/); open the file before running it so you can predict its effect.
`./lab psql` lets you run individual statements yourself. No browser control
executes SQL.

## 1. Find client 42 (slides 3–9, core)

Run `./lab reset` once to restore the starting state, then
`./lab run 01-baseline`. There are 1,000,000 rows, with 1,000 for client 42.
Only the primary key on `id` is initially indexed.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM payments WHERE client_id = 42;
```

Predict: how many rows will the database need to check? Which column would you
index, and why? Write your prediction before running `./lab run 02-client-index`.

| Evidence | Before index | After `(client_id)` |
| --- | --- | --- |
| Scan node(s) and condition | | |
| Estimated output rows | | |
| Actual output rows and loops | | |
| Rows removed by filter | | |
| Shared buffer hits / reads | | |
| Execution time, runs 1 / 2 / 3 (ms) | | |

Explain: what work disappeared? Is a bitmap scan using the index? Why does the
primary key on `id` not solve this query? Does one fast run prove a speedup?

Read the plan from the leaves upward. Costs are planner units, not milliseconds.
`rows` describes output, not every examined row. For multiple loops, actual rows
and node times are averages per loop; parent timings include child work.
Shared buffer counts refer to pages accessed, not rows. A shared read can still
come from the operating system's cache. Building an index also warms caches.

## 2. Common and rare statuses (slide 10, core)

There are 900,000 completed, 10,000 failed and 90,000 pending payments. Predict
separately for each value, then run `./lab run 03-selectivity`. The script removes
only the status index, measures both values three times, creates that index, and
repeats the same measurements. The client index stays in place.

| Query / index state | Predicted route | Observed route | Times, runs 1 / 2 / 3 (ms) | Buffers |
| --- | --- | --- | --- | --- |
| completed / before | | | | |
| failed / before | | | | |
| completed / after | | | | |
| failed / after | | | | |

Explain: why might PostgreSQL keep a sequential scan for completed payments?
What makes the failed query different? Is there a universal matching percentage
at which an index wins? Compare the full `SELECT *` workload throughout;
changing it to `count(*)` may allow an index-only scan and changes the experiment.

## 3. Latest payments (slides 11–12, stretch)

If time is short, skip to costs and the review. Predict whether the existing
client index can supply date order, then run `./lab run 04-composite`.

```sql
SELECT * FROM payments
WHERE client_id = 42
ORDER BY created_at DESC
LIMIT 20;
```

| Evidence | With `(client_id)` | With `(client_id, created_at)` available |
| --- | --- | --- |
| Scan node(s) | | |
| Separate Sort? Sort method? | | |
| Rows emitted by scan below Sort/Limit | | |
| Buffer hits / reads | | |
| Times, runs 1 / 2 / 3 (ms) | | |

Explain: why can the ordered scan stop after 20? Why put client first? Does this
index contain everything needed by `SELECT *`? What does "Backward" mean here?

## 4. Costs and a fresh query (slides 13–15)

Run `./lab run 05-costs` to see storage costs. Its optional write comparison
executes inserts into two temporary tables, then rolls back; `payments` stays
unchanged. Compare the same primary key and constraints with and without three
secondary indices. Reverse-order repeats reduce one ordering effect. These are
temporary-table timings, not production throughput or WAL measurements.

Before running `./lab run 06-review`, propose an index for the query below.
Check which indices already exist. The script only measures; it changes none.

```sql
SELECT * FROM payments
WHERE client_id = 7
  AND created_at >= DATE '2026-03-01'
  AND created_at <  DATE '2026-04-01'
ORDER BY created_at DESC
LIMIT 20;
```

Which work should your candidate remove? How would you test it with another
client or date range? What result would make you reject it? For a fresh baseline,
run `./lab reset` then `./lab run 06-review`; add your proposed index in psql and
run the review again. Do not reset between a baseline and its comparison.

Exit check: explain one plan improvement, one case where scanning is reasonable,
and one cost of adding an index.
