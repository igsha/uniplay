#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which grep jq http jo xargs tee htmlq >/dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.url,(.title // "")' \
    | { read -r URL; read -r TITLE; }

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
fi

echo "videoplayer: Download $URL" >&2
http -F GET "$URL" $REFERER \
    | mapfile HTML

if <<< "${HTML[@]}" grep -Po "subtitles: \K\[[^\]]+\]" | jq -er '.[0] | .src' | read -r SUBURL; then
    basename "$SUBURL" \
        | read -r SUBSNAME
    mktemp -t "uniplay.videoplayer.XXX.$SUBSNAME" \
        | read -r SUBSFILE

    echo "videoplayer: Download subs $SUBURL to $SUBSFILE" >&2
    DOMAIN="${URL%/${URL#*//*/}}"
    http -F GET "$SUBURL" referer:"$DOMAIN" -o "$SUBSFILE"
fi

<<< "${HTML[@]}" htmlq 'video > source' -a src \
    | tee >(xargs printf "videoplayer: Extract %s\n" >&2) \
    | readarray -t URLS

jo -a "${URLS[@]}" \
    | jo list=:- -n title="$TITLE" subsfile="$SUBSFILE" delete="$SUBSFILE" \
    | jq '.list |= map({url: ., title: .})'
