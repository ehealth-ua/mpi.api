# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [2.4.2](https://github.com/edenlabllc/mpi.api/compare/2.4.1...2.4.2) (2019-5-9)




### Bug Fixes:

* idempotency insert (#316)

## [2.4.1](https://github.com/edenlabllc/mpi.api/compare/2.4.1...2.4.1) (2019-5-9)




### Features:

* improved query + improved document indexes (#309)

* idempotency insert (#305)

* mpi: expose create or update person via rpc (#306)

* Deduplication Scheduler (#299)

* add replica on read (#294)

* schedule deduplication with Quantum  (#290)

* Event manager (#288)

* allow to search persons without pagination (#286)

* manual_merger: created ManualMerge application (#277)

* person_deactivator: added libcluster lib with topology for OPS (#272)

* Ecto 3 (#267)

* add version and date of start application into details + app version in build (#266)

* mpi_scheduler: created ManualMergeCreator job (#265)

* deactivator: check updated_at and master declaration before

* extract person filter (#261)

* Deactivator fix kafka push (#255)

* add merge and master links instead of merged_ids (#251)

* added reason for declaration termination producer (#248)

* Read repo (#246)

* ehealth logger (#249)

* no settlement clusters (#238)

* added CandidatesMerger app (#235)

* addresses and partial fields rpc #3045 (#232)

* Kaffe (#230)

* change MergeCandidate score to 1.0 for Person deactivation (#211)

* add manual merge can assign new function (#209)

* add assign manual merge candidate functionality (#207)

* Move rpc module to mpi (#199)

* get person auth method rpc call (#187)

### Bug Fixes:

* deduplication (#314)

* deduplication (#313)

* search persons (#312)

* add person event instead of merge candidate event (#311)

* read replica config (#307)

* index order and duplicate migration (#304)

* sync person documents timestamps with person's (#300)

* set declined status after merge decision for manual merge (#297)

* reduce preloads (#293)

* candidates_merger: Set MergeCanditate declined status on processed ManualMergeRequest split or trash status (#285)

* manual_merger: render nil (#284)

* multimerge (#279)

* person_deactivator: added env var in config (#273)

* person_deactivator: log error in process_merge_candidates (#270)

* phoenix errors logging (#262)

* typo (#253)

* Deduplication improvements (#257)

* not empty (#256)

* kaffe producer (#252)

* ecto logger config (#250)

* Manual Merge Request postpone (#247)

* set Manual Merge Candidate postpone status not final (#245)

* Manual Merge Candidate preload (#244)

* do not mark base Merge Candidate as auto-merge when related candidates are processed (#243)

* Kafka producers (#242)

* update ecto_filter (#234)

* updated kaffe deps path (#233)

* use correct condition on manual merge request assignee_id in get eligible manual merge candidate query

* last_inserted_at retrieving in cleanup_passport_numbers migration (#221)

* Fix producer (#214)

* cleanup_passport_numbers migration now continues work after failure (#216)

* manual_merge: add filter by assignee_id on can_assign_new (#215)

* bump alpine (#203)

* Cron jobs (#192)

* rpc doc (#189)

* correct git_ops module name (#188)
