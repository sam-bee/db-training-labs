# Database training labs

This repository contains repeatable PostgreSQL Docker Compose labs. Lesson 1
covers indices and `EXPLAIN` using the seed in `database/` and exercises in `sql/`.
See `README.md` for installation, `WORKSHEET.md` for exercises, and `LAB-GUIDE.md`
for operational details. `./lab verify` rehearses the exercises in an isolated
database without changing the learner's payments database. Presentation and
tutor development belongs in the separate `db-training-app` repository.

Call teaching units **lessons**; reserve **database session** for a database
connection and its work.

## Docker networking

Every published Compose port must explicitly bind to a loopback IP address:
`127.0.0.1` for IPv4 or `::1` for IPv6. Never publish on all interfaces, use a
bare host-port mapping, or let configuration change the host bind address.
Apply this to every future service, including PostgreSQL and Grafana.

## Version control

Work on `master` by default. Commit completed work in small, coherent changesets
and push it automatically to `origin` (`git@github.com:sam-bee/db-training-labs.git`).
The user explicitly authorized pushes to the configured origin without a
separate confirmation. Keep history linear; use rebase pulls and fast-forward
merges. Prefer short commit messages that explain the reason.
