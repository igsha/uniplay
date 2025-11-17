#!/usr/bin/env bash
set -e
shopt -s lastpipe

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

[[ "$URL" =~ ([^/]+://[^/]+)/ ]]
export DOMAIN="${BASH_REMATCH[1]}"

echo "remanga: Extract $URL" >&2

<<< "${JSON[@]}" "$UNIPLAY" -f remanga-list \
    | "$UNIPLAY" -f remanga-chapter \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
