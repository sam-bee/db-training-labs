# PostgreSQL training labs

Repeatable Docker Compose labs for practical PostgreSQL lessons. Lesson 1 covers
indices and query plans using one million deterministic payments.

## Installation

Install [Docker](https://docs.docker.com/get-started/get-docker/) with Docker
Compose, then run from this directory (use WSL or Git Bash on Windows):

```sh
./lab start
./lab check
```

The first run downloads the PostgreSQL image and creates the sample database.
No host PostgreSQL installation or API keys are needed. Follow the
[lab worksheet](WORKSHEET.md); run `./lab psql` to open a database terminal.

PostgreSQL listens on `127.0.0.1:5433`. If the old lab or another database is
still using that port, copy `.env.example` to `.env` and choose another
`DB_PORT` before starting. This Compose project uses its own database volume;
it does not copy or reuse the old lab's database contents.

Stop with `docker compose down`. Start the exercises over with `./lab reset`.
Run `./lab verify` for a full rehearsal in an isolated temporary database.

See the [lab guide](LAB-GUIDE.md) for exercises, GUI connection details and
troubleshooting, and [recorded plans](reference/README.md) for reference output.
The slideshow and tutor are maintained separately in `db-training-app`.
