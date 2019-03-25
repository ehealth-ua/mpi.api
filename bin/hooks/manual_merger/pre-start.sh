#!/bin/sh

if [ "${DB_MIGRATE}" == "true" ]; then
  echo "[WARNING] Migrating database!"
  ./bin/manual_merger command Elixir.ManualMerger.ReleaseTasks migrate
fi;
