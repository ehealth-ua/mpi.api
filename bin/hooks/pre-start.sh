#!/bin/sh

if [ "${DB_MIGRATE}" == "true" ] && [ -f "./bin/${APP_NAME}" ]; then
  echo "[WARNING] Migrating database!"
  ./bin/mpi command Elixir.MPI.ReleaseTasks migrate
fi;
