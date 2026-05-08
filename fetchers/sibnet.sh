#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http grep >/dev/null

mapfile JSON
<<< "${JSON[@]}" jq -r '.url' \
    | read -r URL

http -F GET "$URL" \
    | grep -Po 'player.src\(\[\{src:\s*"\K[^"]+' \
    | read -r PART

<<< "${JSON[@]}" jq --arg part "$PART" '(.url | split("/")[:3] | join("/")) as $dom
        | .url=$dom + $part
        | .type="video"
        | .referer=$dom'
