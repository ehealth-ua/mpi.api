use Mix.Releases.Config,
  default_release: :default,
  default_environment: :default

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
  set(pre_start_hooks: "bin/hooks/mpi")
  set(version: current_version(:mpi))

  set(
    applications: [
      mpi: :permanent
    ]
  )

  set(config_providers: [ConfexConfigProvider])
end

release :manual_merger do
  set(pre_start_hooks: "bin/hooks/manual_merger")
  set(version: current_version(:manual_merger))

  set(
    applications: [
      manual_merger: :permanent
    ]
  )

  set(config_providers: [ConfexConfigProvider])
end

release :mpi_scheduler do
  set(version: current_version(:mpi_scheduler))

  set(
    applications: [
      mpi_scheduler: :permanent
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

release :person_deactivator do
  set(version: current_version(:person_deactivator))

  set(
    applications: [
      person_deactivator: :permanent
    ]
  )

  set(config_providers: [ConfexConfigProvider])
end
