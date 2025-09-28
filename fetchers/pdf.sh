#!/usr/bin/env bash
set -e

which jq xdg-open > /dev/null

mapfile -t JSON
read -r FILE < <(jq -r .url <<< "${JSON[@]}")

xdg-open "$FILE"
