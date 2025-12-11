#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq htmlq xq > /dev/null

jq -r .item \
    | read -r URL

echo "manga-shi-list: List chapters ${URL%/}/ajax/chapters" >&2
http POST "${URL%/}/ajax/chapters" \
    | htmlq '.main.version-chap' \
    | xq '.ul.li | {items: map(.a | {item: .["@href"], name: .["#text"]}), title: "manga-shi"}'
