# CORRECTIONS.md — mpi.api

Base: ehealth-ua/mpi.api@39a002e (master). User authorized implementation of all viable proposals.

## Implemented

1. **`.gitignore`** — added `.env`, `.env.local`, `.env.production` to prevent committing secrets.
2. **`.env`** — removed from version control (`git rm --cached`), kept on local disk. **Not committed nor exposed.**
3. **`.env.example`** (new) — placeholders for all environment variables, without real values. Instructs to copy to `.env` and fill in.
4. **`README.md`** — expanded with purpose, technologies (Elixir/Phoenix, PostgreSQL, Kafka), architecture, how to install, configure, security, specification.

## Not implemented (requires additional investigation)
- `eHealth-8110bd102a69.json.enc` — encrypted tracked file; content unknown. Not removed without prior investigation.
- `Dockerfile.deduplication` — out of minimum approved scope.

## Validation
- Static review completed.
- Not executed: `mix test`, Docker build (Elixir/Phoenix dependencies not available).
