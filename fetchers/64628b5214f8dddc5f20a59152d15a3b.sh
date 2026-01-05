#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq grep > /dev/null

jq -r '.item, (.item | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r BASEURL; }

URL="$BASEURL/oembed?format=json&url=$URL"
echo "64628b5214f8dddc5f20a59152d15a3b: Download json $URL" >&2
http --follow GET "$URL" \
    | jq -r '.title, .html' \
    | { read -r TITLE; mapfile HTML; }

<<< "${HTML[@]}" htmlq iframe -a src \
    | read -r URL

echo "64628b5214f8dddc5f20a59152d15a3b: Extract jwplayer $URL" >&2
http GET "$URL" "referer:$BASEURL" \
    | grep -Po "window.playlist = \K[^;]+" \
    | jq --arg title "$TITLE" \
        '.sources | max_by(.label | tonumber) | {item: .file, title: $title}' \
    | "$UNIPLAY" -f mpv
