#!/usr/bin/env bash
# Terminal element that download HTML.
set -e
shopt -s lastpipe

which jq http > /dev/null

mapfile JSON
ARGS=()
<<< "${JSON[@]}" jq -r .item \
    | read -r ARGS[0]

if <<< "${JSON[@]}" jq -er '.referer // empty' | read -r REFERER; then
    ARGS+=("referer:$REFERER")
    echo "http: Use referer [$REFERER]" >&2
fi

if <<< "${JSON[@]}" jq -er '.useragent // empty' | read -r UA; then
    ARGS+=("user-agent:$UA")
    echo "http: Use User-Agent [$UA]" >&2
fi

echo "http: Download ${ARGS[0]}" >&2
http GET "${ARGS[@]}"
