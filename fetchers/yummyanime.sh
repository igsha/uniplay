#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http pup >/dev/null

jq -r '.url, (.url | split("/")[0:3] | join("/")), .referer' \
    | { read -r URL; read -r DOMAIN; read -r REFERER; }

if [[ "$URL" =~ //[^/]+/([0-9]+)-.*\.html ]]; then
    ID="${BASH_REMATCH[1]}"
    echo "yummyanime: Find players in $URL" >&2
    http GET "$URL" \
        | pup -p '[data-player-slot] json{}' \
        | jq --arg id "$ID" 'map({
                url: "https://yummyanime.tv/engine/ajax/controller.php?mod=player&id=\($id)&slot=\(.["data-player-slot"])",
                title: .["data-player-title"]
            }) | {
                list: .,
                referer: "https://yummyanime.tv/engine/ajax/controller.php",
                hashkey: "url",
                type: "selectable"
            }'
elif [[ "$URL" =~ /engine/ajax/controller.php ]]; then
    echo "yummyanime: Extract players data from $URL" >&2
    http GET "$URL" "referer:$REFERER" \
        | mapfile JSON

    if <<< "${JSON[@]}" jq -e '.data.kind == "cvh"' >/dev/null; then
        <<< "${JSON[@]}" jq '.data | {
                url: "https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=\(.pub_id)&aggr=\(.aggregator)&id=\(.title_id)"
            }' \
        | "$UNIPLAY" auto
    elif <<< "${JSON[@]}" jq -e '.data.agp == true' >/dev/null; then
        <<< "${JSON[@]}" jq '.data | {url: .src}' \
        | "$UNIPLAY" yummyanime
    else
        echo "yummyanime: Unknown player ${JSON[@]}" >&2
        exit 1
    fi
elif [[ "$URL" =~ /embed/agp ]]; then
    echo "yummyanime: List AGP $URL" >&2
    http GET "$URL" \
        | pup -p 'script:contains("function") text{}' \
        | grep -Po '"kodikSerial":\s"\K[^"]+' \
        | jq -R '{url: .}' \
        | "$UNIPLAY" auto
fi
