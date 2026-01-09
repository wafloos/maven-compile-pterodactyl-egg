#!/bin/ash

TZ=${TZ:-UTC}
export TZ

INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP


PLUGIN_DIR=${PLUGIN_DIR:-plugin-1}
export PLUGIN_DIR

PLUGIN_PATH="/home/container/${PLUGIN_DIR}"
export PLUGIN_PATH

cd /home/container || exit 1


PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")
ing in the output, and then execute it with the env

printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"

exec env ${PARSED}
