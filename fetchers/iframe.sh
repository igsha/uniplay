#!/usr/bin/env bash
set -e
shopt -s lastpipe

which grep http jo jq > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.url,(.title // "")' \
    | { read -r URL; read -r TITLE; }

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
fi

http --follow --timeout 10 GET "$URL" $REFERER \
    | mapfile HTML

<<< "${HTML[@]}" grep -Po '<iframe.*src="\K[^"]+' \
    | sed 's;^//;https://;' \
    | read -r URL

[[ "$URL" =~ [^/]+://[^/]+/ ]]
DOMAIN="${BASH_REMATCH[0]}"

echo "iframe: Extract $URL" >&2

jo url="$URL" referer="$DOMAIN" -n title="$TITLE"
