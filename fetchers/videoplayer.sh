#!/usr/bin/env bash
set -e
shopt -s lastpipe

which grep jq http jo parallel > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.url,(.title // "")' \
    | { read -r URL; read -r TITLE; }

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
fi

http --follow --timeout 5 GET "$URL" $REFERER \
    | mapfile HTML

if <<< "${HTML[@]}" grep -Po "subtitles: \K\[[^\]]+\]" | jq -r '.[0] | .src' | read -r SUBURL; then
    echo "videoplayer: Extract subs $SUBURL" >&2
fi

<<< "${HTML[@]}" htmlq 'video > source' -a src \
    | readarray -t URLS

parallel -k echo "videoplayer: Extract {}" ::: "${URLS[@]}" >&2

jo -a "${URLS[@]}" \
    | jo list=:- -n title="$TITLE" subsurl="$SUBURL" \
    | jq '.list |= map({url: ., title: .})'
