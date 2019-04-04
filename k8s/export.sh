#!/bin/bash

CMDNAME=$(basename $0)
OPTIONS=hn:l:d:
LONGOPTIONS=help,namespace:,label:,dir:

NS="default"
LABEL=""
DIR=`pwd`

function show_help {
    echo "Script to export existed K8s cluster to yaml"
    echo "Usage: "
    echo "      - $CMDNAME [flags]"
    echo ""
    echo "Flags:"
    echo "  -n, --namespace     K8s namespace (default: default)"
    echo "  -l, --label         K8s label. See: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors"
    echo "  -d, --dir           Exported directory (default: current folder)"
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
        -n|--namespace)
            NS="${2:-default}"
            shift 2
            ;;
        -l|--label)
            LABEL="${2:-default}"
            shift 2
            ;;
        -d|--dir)
            DIR="${2:-default}"
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

CMD="kubectl -n $NS get -o=name pvc,configmap,serviceaccount,secret,ingress,service,deployment,statefulset,hpa,job,cronjob"
[[ -z $LABEL ]] || CMD="$CMD -l $LABEL"

list=`eval $CMD`
for c in $list
do
    folder="$DIR/$c"
    mkdir -p $(dirname $folder)
    kubectl -n $NS get -o=yaml --export $c > $folder.yaml
done