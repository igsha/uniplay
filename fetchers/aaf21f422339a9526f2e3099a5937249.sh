#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq > /dev/null

jq -r '.item, (.item | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

while [[ "$URL" =~ /models/ ]]; do
    echo "aaf21f422339a9526f2e3099a5937249: List $URL" >&2
    http --follow --timeout 5 GET "$URL" \
        | htmlq '.list-videos a.thumb_title, #list_videos_common_videos_list_pagination li.next > a' \
        | sed -e '1i<div>' -e '$a</div>' \
        | xq --arg dom "$DOMAIN" '.div.a | . as $arr | {
            items: map(select(.["@class"] == "thumb_title") | {item: .["@href"], name: .["@title"]})
                + map(select(.["@class"] == "link") | {item: $dom + .["@href"], name: "###next###"}),
            title: "aaf21f422339a9526f2e3099a5937249"}' \
        | "$UNIPLAY" -f marksel \
        | jq -r '.item, .title' \
        | { read -r URL; read -r TITLE; }
done

echo "aaf21f422339a9526f2e3099a5937249: Extract $URL" >&2
http --follow GET "$URL" \
    | htmlq 'video > source' \
    | tee >(xargs printf "aaf21f422339a9526f2e3099a5937249: Available %s\n" >&2) \
    | mapfile -t URLS

jo item="${URLS[0]}" title="$TITLE" \
    | "$UNIPLAY" -f mpv
