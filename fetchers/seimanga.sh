#!/usr/bin/env bash
set -e
shopt -s lastpipe

jq -r '.item, (.item | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

echo "seimanga: Extract $URL" >&2
http GET "$URL" \
    | htmlq 'table a' \
    | sed -e '1i<div>' -e '$a</div>' \
    | xq --arg dom "$DOMAIN" '.div.a | {
        items: map({item: $dom + .["@href"] + "?mtr=true", name: .["#text"]}),
        title: "seimanga"}' \
    | "$UNIPLAY" -f marksel \
    | "$UNIPLAY" -f http \
    | grep -oP "readerInit.*\K\[\[.+\]\]" \
    | tr "'" '"' \
    | jq '{items: map(.[0] + (.[2] | split("?")[0]))}' \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
