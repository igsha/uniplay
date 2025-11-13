#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo http htmlq tr sed > /dev/null

mapfile -t JSON
printf "%s\n" "${JSON[@]}" \
    | jq -r .url \
    | read -r URL

echo "manga-shi-chapter: List chapter $URL" >&2
http --follow GET "$URL" \
    | mapfile -t HTML

<<< "${HTML[@]}" htmlq 'head > title' -t \
    | tr '/' '-' \
    | read -r TITLE

<<< "${HTML[@]}" htmlq '.reading-content div > img' -a data-src \
    | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' \
    | jo -a \
    | read -r URLS

jo result=urls urls="$URLS" title="$TITLE"
