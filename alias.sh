#!/bin/bash

### ADD TO ~/.bashrc
alias sudo='sudo '

#### POSTGRESQL
POSTGRES_VERSION=alpine
alias psql="docker run --rm -it --network host postgres:$POSTGRES_VERSION psql"

#### MYSQL
MYSQL_VERSION=latest
alias mysql="docker run --rm -it --network host mysql:$MYSQL_VERSION mysql"