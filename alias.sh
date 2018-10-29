#!/bin/bash

### ADD TO ~/.bashrc
POSTGRES_VERSION=latest
MYSQL_VERSION=latest
alias psql="docker run --rm -it --network host postgres:$POSTGRES_VERSION psql"
alias mysql="docker run --rm -it --network host mysql:$MYSQL_VERSION mysql"