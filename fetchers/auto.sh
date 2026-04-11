#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq >/dev/null

mapfile JSON
if ! <<< "${JSON[@]}" jq -r '.fetcher // empty' | read -r NAME; then
    <<< "${JSON[@]}" jq -r '.url // .file' \
        | read -r ITEM

    if [[ -r "$ITEM" ]]; then
        NAME="${ITEM##*.}"
    elif [[ "$ITEM" =~ [^:]+://([^/]+) ]]; then
        DOMAIN="${BASH_REMATCH[1]}"
        NAME="${DOMAIN%.*}"
        NAME="${NAME##*.}"
    else
        echo "auto: Unexpected arguments or input [$ITEM]" >&2
        exit 1
    fi
else
    <<< "${JSON[@]}" jq 'del(.fetcher)' \
        | mapfile JSON
fi

echo "auto: Determine [$NAME]" >&2
<<< "${JSON[@]}" "$UNIPLAY" "$NAME"
