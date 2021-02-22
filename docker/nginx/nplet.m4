#!/bin/bash

VERSION=1.0.0

# m4_ignore(
echo "This is just a script template, not the script (yet) - pass it to 'argbash' to fix this." >&2
exit 11  #)Created by argbash-init v2.10.0
# ARG_OPTIONAL_SINGLE([directory], [d], [Deployment directory. It will override env:PROXY_PATH if provide])
# ARG_OPTIONAL_SINGLE([name], [n], [Deployment name], [proxy])
# ARG_OPTIONAL_SINGLE([nginx-tmpl], [t], [nginx template file], [https://raw.githubusercontent.com/nginx-proxy/nginx-proxy/master/nginx.tmpl])
# ARG_OPTIONAL_SINGLE([nginx-version], , [nginx image tag: https://hub.docker.com/_/nginx], [alpine])
# ARG_OPTIONAL_SINGLE([docker-gen-image], , [docker-gen image], [jwilder/docker-gen])
# ARG_OPTIONAL_SINGLE([docker-gen-version], , [docker-gen image tag: https://hub.docker.com/r/jwilder/docker-gen], [latest])
# ARG_OPTIONAL_SINGLE([letsencrypt-version], , [letsencrypt-nginx image tag: https://hub.docker.com/r/jrcs/letsencrypt-nginx-proxy-companion], [latest])
# ARG_OPTIONAL_SINGLE([network], [w], [Add nginx stack to Docker network to watch any proxied container], [proxy-network])
# ARG_OPTIONAL_SINGLE([log-driver], [l], [Add log-driver], [json-file])
# ARG_OPTIONAL_SINGLE([compose-opts], [p], [Docker compose CLI options. Must in double/single quote. E.g: Add more compose files: "-f docker-compose.gcloud.yml"])
# ARG_OPTIONAL_SINGLE([command-opts], [o], [Docker compose command options. Must in double/single quote. E.g: Add more "docker-compose up" options: "-d --remove-orphans"])
# ARG_OPTIONAL_SINGLE([any-command], [c], [Any docker-compose command that interacts with nginx-proxy. See: https://docs.docker.com/compose/reference/overview/])
# ARG_OPTIONAL_BOOLEAN([dry-run], , [Dry run], [off])
# ARG_OPTIONAL_BOOLEAN([verbose], , [Turn on verbose mode], [off])
# ARG_POSITIONAL_SINGLE([command], , [Command to execute])
# ARG_TYPE_GROUP_SET([commands], [COMMAND], [command], [init,join,up,stop,restart,down,logs,any], [index])
# ARG_TYPE_GROUP_SET([logDrivers], [driver], [log-driver], [none,local,json-file,syslog,journald,gelf,fluentd,awslogs,splunk,etwlogs,gcplogs,logentries], [index])
# ARG_USE_ENV([PROXY_PATH], , [Deployment directory])
# ARG_HELP([Deploy and manage (n)ginx-(p)roxy-(l)ets(e)ncrypt-(t)ool])
# ARG_VERSION([echo $0 v$VERSION])
# ARG_OPTION_STACKING([getopts])
# ARG_RESTRICT_VALUES([none])
# ARG_POSITIONAL_DOUBLEDASH()
# ARGBASH_SET_DELIM([= ])
# ARGBASH_SET_INDENT([  ])
# ARG_DEFAULTS_POS
# ARGBASH_GO

# [ <-- needed because of Argbash

# vvv  PLACE YOUR CODE HERE  vvv
# ------------------------------

set -e

NC='\033[0m'       #]
RED='\033[0;31m'   #]
GREEN='\033[32m'   #]
YELLOW='\033[33m'  #]
BLUE='\033[34m'    #]
function error() {
    echo -e "$RED$1$NC"
}

function progress() {
    echo -e "$BLUE$1$NC"
}

function success() {
    echo -e "$GREEN$1$NC"
}

function debug() {
    echo -e "$YELLOW$1$NC"
}

CONTAINER_NGINX="nginx-proxy"
CONTAINER_DOCKER_GEN="nginx-proxy-gen"
CONTAINER_LETSENCRYPT="nginx-proxy-le"


NGINX_CONF_FOLDER="conf"
NGINX_CERTS_FOLDER="certs"
NGINX_HTML_FOLDER="html"
NGINX_TMPL_FOLDER="tmpl"
NGINX_VHOST_FOLDER="vhost"
NGINX_HTPASSWD_FOLDER="htpasswd"

DOCKER_COMPOSE_FILE="docker-compose.yml"
DOCKER_COMPOSE_V2_TMPL=$(cat <<-END
version: '2'

services:
  nginx-proxy:
    image: nginx:{{nginx_version}}
    container_name: $CONTAINER_NGINX
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - {{deployment_dir}}/$NGINX_CONF_FOLDER:/etc/nginx/conf.d
      - {{deployment_dir}}/$NGINX_VHOST_FOLDER:/etc/nginx/vhost.d
      - {{deployment_dir}}/$NGINX_HTML_FOLDER:/usr/share/nginx/html
      - {{deployment_dir}}/$NGINX_CERTS_FOLDER:/etc/nginx/certs:ro
      - {{deployment_dir}}/$NGINX_HTPASSWD_FOLDER:/etc/nginx/htpasswd:ro
    labels:
      - "com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy"
    logging:
      driver: {{log_driver}}
    networks:
      - proxy_network

  docker-gen:
    image: {{docker_gen_image}}:{{docker_gen_version}}
    container_name: $CONTAINER_DOCKER_GEN
    command: -notify-sighup nginx-proxy -watch /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf
    restart: always
    volumes_from:
      - nginx-proxy
    volumes:
      - {{deployment_dir}}/$NGINX_TMPL_FOLDER/nginx.tmpl:/etc/docker-gen/templates/nginx.tmpl:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
    labels:
      - "com.github.jrcs.letsencrypt_nginx_proxy_companion.docker_gen"
    logging:
      driver: {{log_driver}}
    networks:
      - proxy_network

  letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion:{{letsencrypt_version}}
    container_name: $CONTAINER_LETSENCRYPT
    restart: always
    volumes_from:
      - nginx-proxy
    volumes:
      - {{deployment_dir}}/$NGINX_CERTS_FOLDER:/etc/nginx/certs:rw
      - /var/run/docker.sock:/var/run/docker.sock:ro
    logging:
      driver: {{log_driver}}
    networks:
      - proxy_network

networks:
  proxy_network:
    external:
      name: {{network}}
END
)


function validate {
    progress "Validating dependencies..."
    local rc
    rc="$(which docker &> /dev/null; echo $?)" && [[ "$rc" != "0" ]] && { error "Docker is not installed"; exit 10; }
    rc="$(which docker-compose &> /dev/null; echo $?)" && [[ "$rc" != "0" ]] && { error "Docker compose is not installed"; exit 10; }
    success "Validation done!!!"
}

function prepare {
    progress "Preparing deployment location..."
    mkdir -p "$1/$NGINX_CONF_FOLDER" "$1/$NGINX_CERTS_FOLDER" "$1/$NGINX_HTML_FOLDER" "$1/$NGINX_TMPL_FOLDER" "$1/$NGINX_VHOST_FOLDER" "$1/$NGINX_HTPASSWD_FOLDER"
    progress "Downloading nginx template: '$_arg_nginx_tmpl'..."
    local nginx_tmpl_file="$1/$NGINX_TMPL_FOLDER/nginx.tmpl"
    local status=$(curl -sL -w "%{http_code}" -o "$nginx_tmpl_file" "$_arg_nginx_tmpl")
    if [[ ! "$status" =~ ^2[[:digit:]][[:digit:]] ]]; then
        debug "$(<"$nginx_tmpl_file")"; rm -rf "$nginx_tmpl_file";
        error "Unable found nginx template '$_arg_nginx_tmpl'"
        error "HTTP status: $status";
        exit 1;
    fi
    success "Prepare deployment done!!!"
}

function generate {
    progress "Generating Docker compose file..."
    if [[ "$_arg_verbose" == "on" ]]; then
        debug "$DOCKER_COMPOSE_V2_TMPL"
    fi
    echo "$DOCKER_COMPOSE_V2_TMPL" | sed \
        -e "s|{{nginx_version}}|$_arg_nginx_version|g" \
        -e "s|{{docker_gen_image}}|$_arg_docker_gen_image|g" \
        -e "s|{{docker_gen_version}}|$_arg_docker_gen_version|g" \
        -e "s|{{letsencrypt_version}}|$_arg_letsencrypt_version|g" \
        -e "s|{{log_driver}}|$_arg_log_driver|g" \
        -e "s|{{network}}|$_arg_network|g" \
        -e "s|{{deployment_dir}}|$1|g" \
        > "$1/$2" 
    success "Generated: $1/$2"
}

function create_docker_network {
    progress "Creating docker network..."
    local rc
    rc="$(docker network ls | grep "$1" &> /dev/null; echo $?)"
    if [[ "$rc" == "0" && "$2" == "true" ]]; then
        rc="$(docker network remove "$1" &> /dev/null; echo $?)"
        [[ "$rc" != "0" ]] && { error "Cannot remove Docker network '$1'"; exit 20; } || success "Removed Docker network '$1'"
    fi
    if [[ "$rc" != "0" || "$2" == "true" ]]; then
        docker network create "$1" &> /dev/null
        success "Created Docker network: '$1'"
    fi
}

DEPLOYMENT_DIR=$([[ -z "$_arg_directory" ]] && ([[ -z "$PROXY_PATH" ]] && echo "$(pwd)" || echo "$PROXY_PATH") || echo "$_arg_directory")
progress "As configuration, nginx proxy is located at '$DEPLOYMENT_DIR'"
DOCKER_COMPOSE_FILE="docker-compose.yml"
DOCKER_ARGS=(-p "$_arg_name" -f "$DEPLOYMENT_DIR/$DOCKER_COMPOSE_FILE")

function dkc_init {
    validate
    prepare "$DEPLOYMENT_DIR"
    generate "$DEPLOYMENT_DIR" "$DOCKER_COMPOSE_FILE"
    create_docker_network "$_arg_network" "true"
}

function dkc_command {
    local args opts
    args=( "${DOCKER_ARGS[@]}" "${_arg_compose_opts// / }" )
    opts=( "${_arg_command_opts// / }" )
    if [[ "$_arg_dry_run" == "on" ]]; then
        echo "docker-compose ${args[*]} $1 ${opts[*]}"
    else
        docker-compose ${args[@]} "$1" ${opts[@]}
    fi
}

function dkc_up {
    if [[ "$_arg_dry_run" != "on" ]]; then
        create_docker_network "$_arg_network" "false"
    fi
    dkc_command up
}


function dkc_join_network {
    create_docker_network "$_arg_network" "false"
    local containers=( "$CONTAINER_NGINX" "$CONTAINER_DOCKER_GEN" "$CONTAINER_LETSENCRYPT" )
    for container in "${containers[@]}"
    do
        (docker network inspect "$_arg_network" | grep -w "$container" >/dev/null 2>&1) || docker network connect "$_arg_network" "$container"
    done
}

case "$_arg_command" in

  init)
    dkc_init
    ;;

  join)
    dkc_join_network
    ;;

  up)
    dkc_up
    ;;

  stop)
    dkc_command stop
    ;;

  restart)
    dkc_command restart
    ;;

  down)
    dkc_command down
    ;;

  logs)
    dkc_command logs
    ;;

  any)
    dkc_command "$_arg_any_command"
    ;;
  *)
    echo -n "unknown command"; exit 199;
    ;;
esac

# ^^^  TERMINATE YOUR CODE BEFORE THE BOTTOM ARGBASH MARKER  ^^^

# ] <-- needed because of Argbash
