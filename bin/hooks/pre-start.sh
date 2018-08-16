#!/bin/sh
# `pwd` should be /opt/mpi

if [ "${DB_MIGRATE}" == "true" ]; then
  echo "[WARNING] Migrating database!"
  ./bin/mpi command Elixir.MPI.ReleaseTasks migrate
fi;
