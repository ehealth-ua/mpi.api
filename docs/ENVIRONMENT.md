# Environment Variables

This environment variables can be used to configure released docker container at start time.
Also sample `.env` can be used as payload for `docker run` cli.

## General

| VAR_NAME      | Default Value           | Description |
| ------------- | ----------------------- | ----------- |
| ERLANG_COOKIE | `03/yHifHIEl`..         | Erlang [distribution cookie](http://erlang.org/doc/reference_manual/distributed.html). **Make sure that default value is changed in production.** |
| LOG_LEVEL     | `info` | Elixir Logger severity level. Possible values: `debug`, `info`, `warn`, `error`. |

## Phoenix HTTP Endpoint

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| APP_PORT          | `4000`        | HTTP host for web app to listen on. |
| APP_HOST          | `localhost`   | HTTP port for web app to listen on. |
| APP_SECRET_KEY    | `b9WHCgR5TGcr`.. | Phoenix [`:secret_key_base`](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html). **Make sure that default value is changed in production.** |

## Database variables

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| DB_NAME | `mpi_dev` | Database name |
| DB_USER | `postgres` | Database user name |
| DB_PASSWORD | `postgres` | Database user password |
| DB_HOST | `travis` | Database host |
| DB_PORT | `5432` | Database port |
| POOL_SIZE | `40` | Database pool size |

## Database variables

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| DB_READ_NAME | `mpi_dev` | Database name |
| DB_READ_USER | `postgres` | Database user name |
| DB_READ_PASSWORD | `postgres` | Database user password |
| DB_READ_HOST | `travis` | Database host |
| DB_READ_PORT | `5432` | Database port |
| READ_POOL_SIZE | `40` | Database pool size |

## Database variables

| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| DB_DEDUPLICATION_NAME | `mpi_dev` | Database name |
| DB_DEDUPLICATION_USER | `postgres` | Database user name |
| DB_DEDUPLICATION_PASSWORD | `postgres` | Database user password |
| DB_DEDUPLICATION_HOST | `travis` | Database host |
| DB_DEDUPLICATION_PORT | `5432` | Database port |
| DEDUPLICATION_POOL_SIZE | `40` | Database pool size |

## Application variables
| VAR_NAME                       | Default Value | Description |
| ------------------------------ | ------------- | ----------- |
| MAX_PERSONS_RESULT             | `15`          | Count of results for pagination when using person search |

## MPI Scheduler variables
| VAR_NAME                                                | Default Value | Description |
| ------------------------------------------------------- | ------------- | ----------- |
| PERSON_AUTO_DEACTIVATION_SCHEDULE                       | `0 0 * * *`   | Cron expression for Person auto deactivation job |
| MANUAL_MERGE_CANDIDATES_CREATOR_SCHEDULE                | `0 0 * * *`   | Cron expression for Manual Merge Candidates creator job |
| PERSON_AUTO_DEACTIVATION_SCORE                          | `0.9`         | Minimal deduplication score for creating Merge Candidate. Between 0 and 1. |
| PERSON_AUTO_DEACTIVATION_BATCH_SIZE                     | `500`         | Batch size of Merge Candidates, that will fetched from MPI DB for Person Deactivation job |
| DEDUPLICATION_MERGE_CANDIDATES_SELECT_BATCH_SIZE        | `500`         | Batch size of Merge Candidates in grey zone, that will fetched from MPI DB for Manual Merge Creator job |
| DEDUPLICATION_MERGE_CANDIDATES_SELECT_MAX_AMOUNT        | `10_000`      | Maximum amount of Merge Candidates that will processed during Manual Merge Creator job |
| DEDUPLICATION_MANUAL_MERGE_CANDIDATES_INSERT_BATCH_SIZE | `100`         | Amount of Manual Merge Candidates for bulk insert into Deduplication DB |
| DEDUPLICATION_MANUAL_SCORE_MIN                          | `0.7`         | Minimal deduplication score range for creating Manual Merge Candidate. Between 0 and 1. |
| DEDUPLICATION_MANUAL_SCORE_MAX                          | `0.9`         | Maximum deduplication score range for creating Manual Merge Candidate. Between 0 and 1. |
