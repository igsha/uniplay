#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq jo sed htmlq > /dev/null

jq -r .item \
    | read -r URL

echo "manga-shi-list: List chapters ${URL%/}/ajax/chapters" >&2
http POST "${URL%/}/ajax/chapters" \
    | mapfile -t HTML

<<< "${HTML[@]}" htmlq 'li a' -t \
    | sed '/^$/d;s/^[[:blank:]]*//;s/[[:blank:]]*$//' \
    | jo -a \
    | mapfile -t NAMES

<<< "${HTML[@]}" htmlq 'li a' -a href \
    | jo -a \
    | mapfile -t URLS

jo result=urls items="$URLS" names="$NAMES" title="manga-shi"
