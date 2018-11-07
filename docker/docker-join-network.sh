#!/bin/bash
NETWORK=$1
FILE=${2:-"./networks.txt"}
[[ -z $NETWORK ]] && { echo "Missing network name"; echo -e "Status: \e[1;31mFailure\e[0m"; exit 1; }
[[ -e $FILE ]] || { echo "Missing network file"; echo -e "Status: \e[1;31mFailure\e[0m"; exit 2; }

while IFS= read -r line
do
	(docker network inspect "$NETWORK" | grep -w "$line" >/dev/null 2>&1) || docker network connect "$NETWORK" "$line"
done < "$FILE"