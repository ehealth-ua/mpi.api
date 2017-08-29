# MPI

[![Build Status](https://travis-ci.org/Nebo15/mpi.api.svg?branch=master)](https://travis-ci.org/Nebo15/mpi.api) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/mpi.api/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/mpi.api?branch=master)

Phoenix app

It stores the patient personal data.

## Specification

- [API docs](http://docs.ehealthapi1.apiary.io/#reference/internal.-master-patients-index)
- [Entity-relation diagram](docs/erd.pdf)
- [Implementation specification](https://edenlab.atlassian.net/wiki/display/EH/%28MPI%29+Master+Patient+Index)

## Installation

You can use official Docker container to deploy this service, it can be found on [nebo15/mpi](https://hub.docker.com/r/nebo15/mpi/) Docker Hub.

### Dependencies

- PostgreSQL 9.6 is used as storage back-end.

## Configuration

See [ENVIRONMENT.md](docs/ENVIRONMENT.md).

## License
 
See [LICENSE.md](LICENSE.md).
