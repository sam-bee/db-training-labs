# Recorded plans and teaching notes

[`plans.txt`](plans.txt) contains actual output from a full rehearsal on
23 October 2026, using PostgreSQL 18.6 in local Docker on Linux x86_64. The file
records image digest and relevant settings. The seed, all six exercises and
three repetitions of each main query are included. These timings describe one
machine with a mostly warm cache; they are not expected learner results.

Run `./lab verify` from the lesson root to generate your own full rehearsal in
`results/verify.log`, including extra repeat-run and reset checks. This does not
alter the learner's database. The six-row slide diagrams remain illustrations;
the annotated plan now uses measured output from this million-row seed.

| Experiment | Before | After | Evidence to discuss |
| --- | --- | --- | --- |
| Client 42 | Sequential scan, 999,000 rows filtered out | Bitmap index + heap scan, 1,000 output rows | Run 3: 9,245 shared hits versus 1,004; 32.292 ms versus 0.327 ms |
| Completed, 90% | Sequential scan | Sequential scan | Most rows are needed; an available index need not be chosen |
| Failed, 1% | Sequential scan | Index scan on status | Run 3: 9,245 shared hits versus 104; 31.959 ms versus 0.829 ms |
| Latest 20 | Bitmap heap scan of 1,000 matches, then top-N sort | Backward composite index scan, 20 output rows, no Sort | Run 3: 1,004 shared hits versus 23; 0.411 ms versus 0.028 ms |
| Write costs, optional | Primary key only | Primary key + three secondary indices | Same 20,000-row insert: 13.846–14.772 ms versus 40.216–43.618 ms across two reversed-order rounds |

The client rows are scattered through the table. The rare status rows occur in
ten blocks of 1,000 rows, making their table fetches relatively compact. Physical
layout matters as well as matching share. Do not generalize a universal scan
threshold from these choices. A different machine or statistics sample may
choose another valid route. Never disable sequential scans to make the exercise
"pass".

After all three secondary indices, this rehearsal used about 72 MB for the table
(including auxiliary storage) and 65 MB for indices, including the primary key.
The single-client index used 7 MB; the composite used 30 MB. They overlap for
some query patterns: do not assume both should remain in a real application.
The insert comparison uses TEMP tables, so it illustrates extra maintenance
without measuring durable production writes, WAL or a full workload.

The closing query uses the existing composite index for client equality, date
range and descending order. If the stretch exercise was skipped, a client index
plus a sort may still be present, or a sequential scan after reset. Ask the
learner to explain that starting state before proposing a change.
