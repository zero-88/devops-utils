#!/bin/bash

CMDNAME=$(basename $0)
COMMAND_OPTS=("md5" "bcrypt" "sha" "ssl" "rand")
OPTIONS=hf:v:p:c:
LONGOPTIONS=help,file:,var:,password:,compute:

PLAIN_PWD=""
FILE=".secret.env"
VAR="ENCRYPTED_PASSWORD"
COMPUTE=5

function separate_command {
    local separator=$1
    COMMAND_STR="$( printf "${separator}%s" "${COMMAND_OPTS[@]}" )"
    COMMAND_STR="${COMMAND_STR:${#separator}}"
}

function show_help {
    separate_command "|"
    echo "Generate password"
    echo "Usage: "
    echo "      - $CMDNAME <$COMMAND_STR> [-p password] [-f file] [-v variable_name] [-c compute]"
    echo "          -p Plain Password. 'rand' no need provide password."
    echo "          -f Write to file. Default: '$FILE'"
    echo "          -v Variable name. Default: '$VAR'"
    echo "          -c Compute round for 'bcrypt' only. Default: '$COMPUTE'"
}

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
        -f|--file)
            FILE="${2:-default}"
            shift 2
            ;;
        -p|--password)
            PLAIN_PWD="$2"
            shift 2
            ;;
        -v|--var)
            VAR="${2:-default}"
            shift 2
            ;;
        -c|--compute)
            COMPUTE="${2:-default}"
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

function gen_random_pwd {
    echo "Generating OpenSSL random in $1";
    echo "export $2='$(openssl rand -hex 32)'" >> $1;
}

function gen_openssl_pwd {
    echo "Generating OpenSSL in $1 with var $3";
    echo "export $3='$(openssl passwd -crypt $2)'" >> $1;
}

function gen_sha_pwd {
    echo "Generating SHA password in $1 with var $3";
    echo "export $3='$(docker run --rm httpd:2.4-alpine htpasswd -nbs admin "$2" | cut -d ":" -f 2)'" >> $1;
}

function gen_md5_pwd {
    echo "Generating MD5 password in $1 with var $3";
    echo "export $3='$(docker run --rm httpd:2.4-alpine htpasswd -nbm admin "$2" | cut -d ":" -f 2)'" >> $1;
}

function gen_bcrypt_pwd {
    echo "Generating BCrypt password in $1 with var $3 - compute $4";
    echo "export $3='$(docker run --rm httpd:2.4-alpine htpasswd -nbB -C $4 admin "$2" | cut -d ":" -f 2)'" >> $1;
}

ALGORITHM=$COMMAND
echo "" >> $FILE;
if [[ $ALGORITHM == "rand" ]]; then
    gen_random_pwd $FILE $VAR
else
    [[ -z $PLAIN_PWD ]] && { echo -e "$(basename $0): Must provide a password"; echo -e "Status: \e[1;31mFailure\e[0m"; exit 3; }
    if [[ $ALGORITHM == "sha" ]]; then
        gen_sha_pwd $FILE $PLAIN_PWD $VAR
    elif [[ $ALGORITHM == "ssl" ]]; then
        gen_openssl_pwd $FILE $PLAIN_PWD $VAR
    elif [[ $ALGORITHM == "md5" ]]; then
        gen_md5_pwd $FILE $PLAIN_PWD $VAR
    elif [[ $ALGORITHM == "bcrypt" ]]; then
        gen_bcrypt_pwd $FILE $PLAIN_PWD $VAR $COMPUTE
    else
        echo -e "$(basename $0): Algorithm is not available";
        echo -e "Status: \e[1;31mFailure\e[0m";
        exit 4;
    fi
fi
echo -e "Status: \e[1;32mSuccess\e[0m"