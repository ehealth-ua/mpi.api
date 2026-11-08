# MPI - Master Patient Index (EHealth Ukraine)

Phoenix application that stores patient personal data.

## Description

MPI (Master Patient Index) is an Elixir/Phoenix service for patient identification
and matching in the Ukrainian eHealth system. It stores patient personal data and
provides APIs for patient lookup, matching, and deduplication.

## Architecture

- Elixir/Phoenix web application
- PostgreSQL 9.6+ storage backend
- Kafka for event streaming
- Docker for containerized deployment
- Mix/Elixir build tool

## Directory structure

- `apps/` — Elixir umbrella applications (core, candidates_merger, etc.)
- `config/` — application configuration
- `bin/` — release scripts
- `rel/` — release artifacts
- `doc/` — documentation
- `docs/` — additional docs (including ENVIRONMENT.md)
- `Dockerfile` — container image definition

## Installation

You can use the official Docker container to deploy this service, available on
[edenlabllc/mpi](https://hub.docker.com/r/edenlabllc/mpi/) Docker Hub.

### Dependencies

- PostgreSQL 9.6 is used as storage back-end.
- Kafka for message streaming.

## Configuration

See `docs/ENVIRONMENT.md` for environment variable configuration.

Copy `.env.example` to `.env` and fill in real values before running locally.
Never commit `.env` with real secrets.

## License

See `LICENSE.md`.

## Specification

- [API docs](http://docs.ehealthapi1.apiary.io/#reference/internal.-master-patients-index)
- [Entity-relation diagram](docs/erd.pdf)
- [Implementation specification](https://edenlab.atlassian.net/wiki/display/EH/%28MPI%29+Master+Patients+Index)
