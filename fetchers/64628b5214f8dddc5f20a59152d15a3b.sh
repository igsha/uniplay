#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq grep > /dev/null

jq -r '.url, (.url | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r BASEURL; }

echo "64628b5214f8dddc5f20a59152d15a3b: Download html $URL" >&2
http -F GET "$URL" \
    | htmlq 'script[type="application/ld+json"]' -t \
    | jq -r '.name, .embedUrl' \
    | { read -r TITLE; read -r URL; }

echo "64628b5214f8dddc5f20a59152d15a3b: Extract jwplayer $URL" >&2
http GET "$URL" "referer:$BASEURL" \
    | grep -Po "window.playlist = \K[^;]+" \
    | jq --arg title "$TITLE" '.sources | max_by(.label | tonumber) | {
        url: .file,
        title: $title,
        type: "video"}'
