#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo xargs > /dev/null

jq -r .item \
    | xargs grep -v "^#" \
    | jo -a \
    | jq '{items: map({item: ., name: .}), title: "ulst"}' \
    | "$UNIPLAY" -f selector \
    | jq -r .item \
    | read -r URL

echo "ulst: Extract $URL" >&2
jo result=url item="$URL"
