# PostgreSQL training — lesson 1

For lesson 2's separate locking database, setup, ordered scripts, and verification,
see the [lesson 2 worksheet](lesson-2/WORKSHEET.md) and
[rehearsed observations](lesson-2/REFERENCE.md). Run `./lab locking reset` after
startup, then open `./lab locking a`, `b`, and `observer` in separate terminals.

A one-hour lesson on indices and query performance, with repeatable PostgreSQL
experiments. The labs use one million deterministic payments and follow the
same queries as the slides maintained separately in `db-training-app`.

## Start before the lesson

Install Docker with Docker Compose v2 or later. On Windows, run the shell
commands in WSL or Git Bash. From this directory:

```sh
./lab start
./lab check
```

The first run pulls the PostgreSQL image and seeds the database; allow a few
minutes and roughly 1 GB of free disk space. Once the image is downloaded,
the labs work offline without API keys. No host PostgreSQL, Node, npm or Python
install is needed. The database health check waits until seeding has finished.

## Run the experiments

Keep the [worksheet](WORKSHEET.md) open to record predictions and results.
Open each SQL file before running it; the file runs all of its before/after
steps automatically. To work statement by statement instead, use `./lab psql`
and paste SQL from the files. Type `\q` to leave psql.

```sh
./lab reset                    # Fresh data and only the primary-key index
./lab run 01-baseline          # Read EXPLAIN; measure the client lookup 3 times
./lab run 02-client-index      # Add (client_id), repeat the same query 3 times
./lab run 03-selectivity       # completed vs failed, before/after (status)
./lab run 04-composite         # Stretch: latest 20, before/after (client_id, created_at)
./lab run 05-costs             # Storage and optional disposable-table inserts
./lab run 06-review            # Closing client/date-range challenge
```

The first two experiments are the core of the hour. Skip the composite stretch
if time is short and preserve the costs discussion and review. Scripts 03 and
04 rebuild their own candidate index to make repeat comparisons possible; 02
keeps an existing client index. To repeat the whole lesson from its baseline,
run `./lab reset` first. Do not reset between 01 and 02.

Each plan query runs three times on each side of the comparison. Record the
scan, estimated/actual rows, sort, buffers and all three execution times.
`EXPLAIN ANALYZE` actually executes SQL. The main experiments use SELECT;
05 explicitly inserts into temporary tables and rolls back. It never changes
the payments data. Index build time, cache state and machine load affect results;
no exact scan label or speedup is required.

For a single query or a single repeat from the terminal:

```sh
./lab psql -c 'EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM payments WHERE client_id = 42;'
./lab psql -f /lab/sql/queries/latest.sql
```

To save output locally (the `results/` directory is ignored by Git):

```sh
mkdir -p results
./lab run 01-baseline > results/01-baseline.txt
```

[Recorded plans and teaching notes](reference/README.md) provide a rehearsed
example for discussion if a learner's machine is unavailable. Slides contain
recorded plan excerpts and schematic diagrams, explicitly distinguished from
live execution. Browser controls do not run SQL.

## Connect with a database GUI

| Setting | Value |
| --- | --- |
| Host | `127.0.0.1` |
| Port | `5433` (or `DB_PORT` from `.env`) |
| Database | `payments` |
| User | `student` |
| Password | `student` |
| SSL mode | Disable for this local lab |

These fixed credentials belong to the disposable local training database.
Published ports always bind to `127.0.0.1`; only port numbers are configurable.
`./lab psql` connects inside the container and does not need the host port.

## Data, reset and persistence

`payments(id, client_id, created_at, status, amount)` starts with only its primary
key on `id`. SQL generates exactly 1,000,000 rows: 1,000 clients, 1,000 payments
per client, dates spread through 2026, positive amounts, 90% completed, 1% failed,
and 9% pending. Status varies independently of client ID. No randomness, current
time or external data is used. The six-row slide illustrations are separate;
their example IDs and row locations are not seed records.

The seed runs automatically for a new Docker volume. `VACUUM (ANALYZE)` prepares
the table and planner statistics after seeding. Statistics are sampled; estimates
and timings may vary even when the data is identical. PostgreSQL is pinned to
`18.6-bookworm`. Parallel query and JIT are disabled to keep the early plans
readable; scan methods and planner costs use defaults. To investigate parallel
plans later, try `SET max_parallel_workers_per_gather = 2;` in a psql session.

`./lab reset` replaces **only `public.payments`**, including its indices, with
that seed. It discards changes made to the exercise table, so close other lab
transactions first. Other tables stay in place. Run `./lab check` to check
counts, dates and current index definitions.
After a reset, its index list should show only `payments_pkey`.

Stop everything, keeping database contents:

```sh
docker compose down
```

For a complete database reinitialization, `docker compose down --volumes`
removes this project's database volume. The next startup seeds again. Use this
only when you intend to discard the training database, for example after a
failed first initialization. Plain restarts do not reseed an existing volume.

## Rehearse and verify

```sh
./lab verify
```

This starts the database if necessary, creates an isolated temporary database,
runs all exercises and repeat runs, checks the seed contents and index states,
verifies all payment values stayed unchanged, and checks reset determinism.
It drops that temporary database on exit. Your `payments` database is preserved.
Plans and diagnostic output are saved to `results/verify.log`. It checks working
SQL and data integrity rather than asserting hardware-dependent timings or scan
choices. Inspect the plans to assess the lesson's intended comparisons.

## Configuration and troubleshooting

Copy `.env.example` to `.env` to change `DB_PORT` (default 5433), then repeat
startup. Use the new port in GUI connections. The `.env` file is ignored by Git.
If the old lab is still running on port 5433, choose another port here before
starting. This project creates its own database volume and seeds fresh data;
it does not reuse the old lab's volume or any changes made there.

- Port already in use: set a different port number in `.env`, or stop the
  conflicting service. The bind address remains loopback.
- Database startup fails: inspect `docker compose logs db`. For a failed initial
  seed, use the complete reinitialization command above; for a running database
  with missing/changed exercise data, use `./lab reset`.
- Helper says the service is not running: run `./lab start`.
- Unexpected index or plan: run `./lab check`; reset before repeating the lesson.
  Index or bitmap scans are both valid, and scanning the common status is useful
  evidence. Keep the query and parameters identical between comparisons.
- Docker permission error: ensure Docker Desktop/Engine is running and your
  shell can access it, as required by your Docker installation.

## Development and sources

See the SQL files in [`sql/`](sql/) and use `./lab verify` to rehearse changes.
The slideshow and tutor are maintained separately in `db-training-app`.
The database service uses the
[official PostgreSQL image](https://hub.docker.com/_/postgres), including its
PostgreSQL 18 data-volume layout and initialization scripts.

The teaching method follows PostgreSQL's documentation for
[EXPLAIN](https://www.postgresql.org/docs/18/using-explain.html),
[multicolumn indices](https://www.postgresql.org/docs/18/indexes-multicolumn.html),
[index ordering](https://www.postgresql.org/docs/18/indexes-ordering.html), and
[index maintenance costs](https://www.postgresql.org/docs/18/indexes-intro.html).
