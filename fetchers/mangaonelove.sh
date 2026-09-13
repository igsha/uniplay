#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http htmlq grep xq pup parallel seq >/dev/null

jq -r .url \
    | read -r URL

http --follow GET "$URL" \
    | mapfile HTML

if [[ "$URL" =~ /manga-reader/[^/]+ ]]; then
    echo "mangaonelove: Extract info $URL" >&2
    <<< "${HTML[@]}" htmlq title -t \
        | read -r TITLE

    <<< "${HTML[@]}" pup 'script:contains("var mrpData")' \
        | grep -Po "(?:mangaId|totalPages|volume|chapter|page):\s*\K\d+|(?:ajaxUrl|nonce):\s*'\K[^']+" \
        | { read -r APIURL; read -r NONCE; read -r MANGAID; read -r VOLUME; read -r CHAPTER; read -r PAGE; read -r TOTALPAGES; }

    echo "mangaonelove: Extract pages $PAGE-$TOTALPAGES from $APIURL [$MANGAID]" >&2
    seq "$PAGE" "$TOTALPAGES" \
        | parallel -kq http --ignore-stdin -f POST "$APIURL" \
                manga_id="$MANGAID" \
                nonce="$NONCE" \
                volume="$VOLUME" \
                chapter="$CHAPTER" \
                page="{1}" \
                action=mrp_load_page \
        | jq -s --arg title "$TITLE" 'map(.data.image_url | {
                url: .,
                title: (. | split("/")[-1])
            }) | {
                list: .,
                title: $title,
                pipeline: "manga",
                type: "images"
            }'
elif [[ "$URL" =~ /manga/ ]]; then
    echo "mangaonelove: List chapters $URL" >&2
    <<< "${HTML[@]}" htmlq '#chapters-list-container .chapter-item' \
        | htmlq \
        | xq '[.. | objects | select(has("@class") and (.["@class"] | startswith("chapter-item")))] | {
                list: map({url: .["@href"], title: .span[0].["#text"]}),
                hashkey: "url",
                type: "selectable",
                title: "mangaonelove"
            }'
else
    echo "mangaonelove: Unsupported url $URL" >&2
    exit 1
fi
