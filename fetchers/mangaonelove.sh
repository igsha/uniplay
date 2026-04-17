#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq grep xq > /dev/null

jq -r '.url // empty' \
    | read -r URL

http --follow GET "$URL" \
    | mapfile HTML

if [[ "$URL" =~ /manga/[^/]+/.+ ]]; then
    echo "mangaonelove: Extract chapter $URL" >&2
    <<< "${HTML[@]}" htmlq title -t \
        | read -r TITLE

    <<< "${HTML[@]}" htmlq '#chapter_preloaded_images' -t \
        | grep -Po '\[.+\]' \
        | jq --arg title "$TITLE" '{list: map({url: .}), title: $title, pipeline: "manga", type: "images"}'
else
    echo "mangaonelove: List chapters $URL" >&2
    <<< "${HTML[@]}" htmlq 'ul.main.version-chap' --remove-nodes .c-new-tag \
        | xq '[.. | objects | select(has("@class") and (.["@class"] | startswith("wp-manga-chapter"))) | .a] | {
                list: map({url: .["@href"], title: .["#text"]}),
                hashkey: "url",
                type: "selectable",
                title: "mangaonelove"
            }'
fi
