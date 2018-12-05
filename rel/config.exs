use Mix.Releases.Config,
  default_release: :default,
  default_environment: :default

#
# cookie = :sha256
# |> :crypto.hash(System.get_env("ERLANG_COOKIE") || "f0HC3ImpJ93mYir8Fu3gveUxm0Tpe1jLBBpxb3YP4n+oHabt/CKGOs1a89UDfW0E")
# |> Base.encode64

environment :default do
  set(dev_mode: false)
  set(include_erts: true)
  set(include_src: false)

  set(
    overlays: [
      {:template, "rel/templates/vm.args.eex", "releases/<%= release_version %>/vm.args"}
    ]
  )
end

release :mpi do
  set(pre_start_hooks: "bin/hooks/")
  set(version: current_version(:mpi))

  set(
    applications: [
      mpi: :permanent
    ]
  )

  set(config_providers: [ConfexConfigProvider])
end

release :person_updates_producer do
  set(version: current_version(:person_updates_producer))

  set(
    applications: [
      person_updates_producer: :permanent
    ]
  )

  set(config_providers: [ConfexConfigProvider])
end

release :deduplication do
  set(version: current_version(:deduplication))

  set(
    applications: [
      deduplication: :permanent
    ]
  )

  set(config_providers: [ConfexConfigProvider])
end
