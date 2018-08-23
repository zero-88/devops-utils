#!/bin/bash

CMDNAME=$(basename $0)
COMMAND_OPTS=("backup" "restore")
OPTIONS=hu:v:f:b:
LONGOPTIONS=help,user:,volume:,folder:,backup:

function separate_command {
    local separator=$1
    COMMAND_STR="$( printf "${separator}%s" "${COMMAND_OPTS[@]}" )"
    COMMAND_STR="${COMMAND_STR:${#separator}}"
}

function show_help {
    separate_command "|"
    echo "Backup/Restore Docker volume"
    echo "Usage: "
    echo "      - $CMDNAME <$COMMAND_STR> [-u user] [-v volume] [-f folder] [-b backup]"
    echo "          -u User Id in container. Default: current user id that trigger command."
    echo "          -v Container volume name"
    echo "          -f Working folder name. Must be absolute path"
    echo "          -b Backup file name"
}

USER_ID=`id -u $USER`
VOLUME_NAME=""
WORKING_FOLDER=""
BACKUP_FILE=""

## PARSER OPTS
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
[[ $? -ne 0 ]] && { echo -e "Status: \e[1;31mFailure\e[0m"; exit 2; }
eval set -- "$PARSED"
while true; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--user)
            USER_ID="${2:-default}"
            shift 2
            ;;
        -v|--volume)
            VOLUME_NAME="$2"
            shift 2
            ;;
        -f|--folder)
            WORKING_FOLDER="$2"
            shift 2
            ;;
        -b|--backup)
            BACKUP_FILE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
done

COMMAND=${1,,}
separate_command " "
[[ $COMMAND_STR =~ (^|[[:space:]])"$COMMAND"($|[[:space:]]) ]] \
    || { echo -e "$0: Command is not available"; echo -e "Status: \e[1;31mFailure\e[0m"; exit 4; }

function backup {
    [[ -z $4 ]] && local backup_file=`date +%Y%m%d`-$2.tar || local backup_file=$4
    docker run --rm -u $1 -v /tmp/:/tmp/ -v $2:$3 busybox tar cvf /tmp/$backup_file $3
    echo "Backup success to /tmp/$backup_file"
}

function restore {
    [[ -z $4 ]]  && { echo -e "Missing Backup file name. Status: \e[1;31mFailure\e[0m"; exit 1; }
    local level=$(echo $3 | tr -cd '/' | wc -c)
    [[ "${str: -1}" == "/" ]] && level=$(( level - 1 ))
    docker run --rm -u $1 -v /tmp/:/tmp/ -v $2:$3 busybox /bin/sh -c "tar xvf /tmp/$4 -C $3 --strip $level;"
}

[[ -z $VOLUME_NAME ]] && { echo -e "Missing Volume name. Status: \e[1;31mFailure\e[0m"; exit 1; }
[[ -z $WORKING_FOLDER ]] && { echo -e "Missing Working folder. Status: \e[1;31mFailure\e[0m"; exit 1; }

if [[ $COMMAND == "backup" ]]; then
    backup $USER_ID $VOLUME_NAME $WORKING_FOLDER $BACKUP_FILE
elif [[ $COMMAND == "restore" ]]; then
    restore $USER_ID $VOLUME_NAME $WORKING_FOLDER $BACKUP_FILE
else
    echo -e "$(basename $0): Command is not available";
    echo -e "Status: \e[1;31mFailure\e[0m";
    exit 4;
fi
echo -e "Status: \e[1;32mSuccess\e[0m"
exit 0
