use Mix.Releases.Config,
  default_release: :default,
  default_environment: :default
#
#cookie = :sha256
#|> :crypto.hash(System.get_env("ERLANG_COOKIE") || "f0HC3ImpJ93mYir8Fu3gveUxm0Tpe1jLBBpxb3YP4n+oHabt/CKGOs1a89UDfW0E")
#|> Base.encode64

environment :default do
  set pre_start_hook: "bin/hooks/pre-start.sh"
  set dev_mode: false
  set include_erts: false
  set include_src: false
#  set cookie: cookie
end

release :mpi do
  set version: current_version(:mpi)
  set applications: [
    mpi: :permanent
  ]
end
