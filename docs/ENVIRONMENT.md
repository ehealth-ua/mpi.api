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

## Application variables
| VAR_NAME      | Default Value | Description |
| ------------- | ------------- | ----------- |
| MAX_PERSONS_RESULT | `15` | Count of results for pagination when using person search |
