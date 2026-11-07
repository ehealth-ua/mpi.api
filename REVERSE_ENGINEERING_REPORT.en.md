# REVERSE ENGINEERING REPORT — ehealth-ua/mpi.api

## Original repository
- Name: mpi.api
- URL: https://github.com/ehealth-ua/mpi.api
- Type: Master Patient Index (MPI) — Phoenix/Elixir for patient identification (eHealth Ukraine)
- Branch: master
- Base: 39a002e [ci skip] chore: release version 2.5.0 (#333)

## Audit date
2026-11-07

## Tools used
- Git v2.49.0
- PowerShell 5.1
- gh (GitHub CLI), authenticated as admeduardovieira
- Kilo Code (static analysis of Elixir/YAML/JSON/markdown files)

## Identified architecture
Phoenix/Elixir application for Master Patient Index (patient identification) of the Ukrainian eHealth system. Umbrella architecture with multiple Mix applications. Stores patient personal data and provides APIs for lookup, matching and deduplication.

Main components:
- `apps/core/` — core application (business logic, models, RPC)
- `apps/candidates_merger/` — candidate merging, Kafka producer
- `config/` — configuration per environment (dev/test/prod)
- `bin/` — release scripts
- `rel/` — release artifacts
- `Dockerfile` / `Dockerfile.deduplication` — Docker images

## Technologies and dependencies
- Elixir / Phoenix
- Erlang/OTP
- PostgreSQL 9.6+
- Kafka
- Mix (build tool)
- Distillery (releases)
- ExCoveralls (coverage)
- Credo (lint)

## Maintenance status
- ~333 commits
- Master branch active
- 2 Dependabot Issues/PRs open (numpy, scipy — Python dependencies)
- Tests exist in `apps/*/test/`
- CI via Travis CI (`.travis.yml`)

## Investigation limitations
- No Elixir/Phoenix environment to run tests or build
- Could not execute automated tests

---

## Problems found (mpi.api)

| ID | Sev | Status | Location | Problem | Fix applied |
|---|---|---|---|---|---|
| REA-001 | P0 | CONFIRMED | `.env` (tracked) | Environment file with real credentials versioned: `ERLANG_COOKIE`, `DB_PASSWORD=postgres`, `APP_SECRET_KEY`, `DB_*_PASSWORD=postgres` | `.env` added to `.gitignore` and removed from version control (`git rm --cached`) |
| REA-002 | P2 | CONFIRMED | `.env.example` (missing) | No `.env` example for developers; risk of committing real `.env` | `.env.example` created with empty placeholders (no secrets) |
| REA-003 | P3 | CONFIRMED | `README.md` | Minimal README (29 lines); no security instructions, detailed architecture or `.env` warning | README expanded with architecture, dependencies, structure, installation, configuration, security |
| REA-004 | P2 | PROBABLE | `eHealth-8110bd102a69.json.enc` | Encrypted JSON file tracked in repository; content unknown, possible service key | Not fixed (requires content investigation before deciding removal) |
| REA-005 | P3 | PROBABLE | `Dockerfile.deduplication` | Separate Dockerfile for deduplication without clear documentation | Not fixed (out of minimum scope) |

## Recurring problems
- 2 open Dependabot PRs (numpy 1.15.4→1.22.0, scipy 1.1.0→1.10.0) — outdated Python dependencies, not resolved satisfactorily.

## Undocumented errors (new from audit)
REA-001, REA-002, REA-003, REA-004, REA-005 have no visible public record.

## Changes implemented (Phase 2)
1. `.gitignore`: `.env`, `.env.local`, `.env.production` added.
2. `.env`: removed from version control (`git rm --cached`), kept on disk.
3. `.env.example` (new): placeholders for all variables, no real values.
4. `README.md`: expanded with architecture, dependencies, structure, how to install, configure, security, specification.

## Changes NOT implemented
- REA-004: `eHealth-8110bd102a69.json.enc` — requires content investigation before removal.
- REA-005: `Dockerfile.deduplication` — out of minimum scope.

## Validation performed
- Static review of Elixir/YAML/markdown files.
- Not executed: `mix test`, Docker build (Elixir/Phoenix dependencies not available).

## Remaining risks
- Credentials may already have been exposed in git history (`.env` was tracked by previous commits). Recommends rotating `ERLANG_COOKIE`, `DB_PASSWORD`, `APP_SECRET_KEY`, etc.
- `eHealth-*.json.enc` still tracked — content unknown.

## Recommendations for future audits
- Rotate all credentials that were in versioned `.env`.
- Investigate content of `eHealth-*.json.enc`.
- Run `mix test` and `mix credo` when Elixir environment available.
- Resolve pending Dependabot PRs.
