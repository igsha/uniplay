#!/usr/bin/env bash
set -e

which jq > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .item <<< "${JSON[@]}")
read -r URL < <(grep -v "^#" "$URL" | fzf)

export URL
echo "ulst: Extract $URL" >&2
jq '.result="url" | .item=env.URL' <<< "${JSON[@]}"
