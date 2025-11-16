#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

[[ "$URL" =~ [^/]+//[^/]+/manga/([^/]+)/([0-9]+) ]]
URL="https://api.remanga.org/api/v2/titles/chapters/${BASH_REMATCH[2]}/"
export TITLE="${BASH_REMATCH[1]}"

echo "remanga-chapter: Download chapter $URL" >&2
http GET "$URL" \
    | jq '.pages | flatten | map(.link) | {results: "urls", items: (.), title: env.TITLE}'
