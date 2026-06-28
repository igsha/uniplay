#!/usr/bin/env bash
set -e
shopt -s lastpipe

which grep jq http jo xargs tee htmlq >/dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.url,(.title // "")' \
    | { read -r URL; read -r TITLE; }

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
fi

echo "videoplayer: Download $URL" >&2
http --follow GET "$URL" $REFERER \
    | mapfile HTML

if <<< "${HTML[@]}" grep -Po "subtitles: \K\[[^\]]+\]" | jq -r '.[0] | .src' | read -r SUBURL; then
    echo "videoplayer: Extract subs $SUBURL" >&2
fi

<<< "${HTML[@]}" htmlq 'video > source' -a src \
    | tee >(xargs printf "videoplayer: Extract %s\n" >&2) \
    | readarray -t URLS

jo -a "${URLS[@]}" \
    | jo list=:- -n title="$TITLE" subsurl="$SUBURL" \
    | jq '.list |= map({url: ., title: .})'
