#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo htmlq xq sed pup >/dev/null

jq -r '.url, (.url | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ [^/]+://[^/]+/manga/[^/]+/?$ ]]; then
    URL="${URL%/}/chapters/?chapter_sort=latest"
fi

if [[ "$URL" =~ /chapters/ ]]; then
    echo "manga-shi: List chapters $URL" >&2
    http --follow GET "$URL" \
        | mapfile HTML

    <<< "${HTML[@]}" pup -p '#page-content nav json{}' \
        | jq -r '.[1].children[-1].href' \
        | read -r NEXTURL

    <<< "${HTML[@]}" pup -p '#page-content #chapters-list a json{}' \
        | jq --arg dom "$DOMAIN" --arg nexurl "$NEXTURL" --arg url "${URL%\?*}" 'map({
                url: $dom + .href,
                title: .children[0].children[1].text
            }) + if $nexurl != "null" then [{
                url: $url + $nexurl,
                title: "###next###"
            }] else [] end | {
                list: .,
                hashkey: "url",
                type: "selectable",
                title: "manga-shi"
            }'
elif [[ "$URL" =~ /manga/[^/]+/tom-[0-9]+/glava-[0-9]+ ]]; then
    echo "manga-shi: Download chapter $URL" >&2

    http --follow GET "$URL" \
        | pup '.reader-pages .reader-page img json{}' \
        | jq --arg base "$DOMAIN" '.[0].title as $title | map($base + (.["data-src"] // .src) | {
                url: .,
                title: (. | split("/")[-1])
            }) | {
                list: .,
                parallel: 4,
                title: $title,
                type: "images",
                pipeline: "manga"
            }'
else
    echo "manga-shi: Wrong url $URL" >&2
    exit 1
fi
