#!/usr/bin/env bash
set -e

which grep http jo > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")
if read -r REFERER < <(jq -r '.referer // empty' <<< "${JSON[@]}"); then
    REFERER="referer:$REFERER"
fi

read -r REGISTER < <(mktemp -t uniplayer.iframe.XXX)
trap "rm \"$REGISTER\"" INT EXIT
http --follow --timeout 5 GET "$URL" $REFERER > "$REGISTER"

read -r URL < <(grep -Po '<iframe.*src="\K[^"]+' "$REGISTER" | sed 's;^//;https://;')
read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$URL")
echo "iframe: Extract $URL" >&2

export URL DOMAIN
<<< "${JSON[@]}" jq '.result="url" | .url=env.URL | .referer=env.DOMAIN'
