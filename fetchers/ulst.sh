#!/usr/bin/env bash
set -e

which jq > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")
read -r URL < <(grep -v "^#" "$URL" | fzf)

export URL
echo "ulst: Extract $URL" >&2
jq '.result="url" | .url=env.URL' <<< "${JSON[@]}"
