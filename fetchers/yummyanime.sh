#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http pup >/dev/null

jq -r '.url, (.url | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ //[^/]+/[0-9]+-.*\.html ]]; then
    echo "yummyanime: Find players in $URL" >&2
    http GET "$URL" \
        | pup -p '.cvh, .xfplayer json{}' \
        | mapfile JSON

    URLS=()
    if <<< "${JSON[@]}" jq -e '.[] | select(.["data-pub"])' >/dev/null; then
        echo "yummyanime: Extract CVH player" >&2
        <<< "${JSON[@]}" jq -r '.[] | select(.["data-pub"]) |
                "https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=\(.["data-pub"])&aggr=mali&id=\(.["data-mali"])"' \
            | mapfile -t -O 0 URLS
    fi

    <<< "${JSON[@]}" jq -r '.[] | select(.["data-params"]) |
            "https://yummyanime.tv/engine/ajax/controller.php?" + .["data-params"]' \
        | mapfile -t CONTROLLER_URLS

    for URL in "${CONTROLLER_URLS[@]}"; do
        echo "yummyanime: Extract player by $URL" >&2
        http GET "$URL" \
            | jq -r .data \
            | mapfile -O "${#URLS[@]}" -t URLS
    done

    printf "%s\n" "${URLS[@]}" \
        | jq -Rn '[inputs] | map({
                url: .,
                title: .
            }) | {
                list: .,
                title: "yummyanime",
                hashkey: "url",
                type: "selectable"
            }'
else
    echo "yummyanime: List films $URL" >&2
    http GET "$URL" \
        | pup '#dle-content .movie-item__link, #dle-content .pagination json{}' \
        | jq --arg dom "$DOMAIN" 'map((select(.id == "pagination") | {
            url: .children[0].children[1].href,
            title: "###next###"
        }) // (select(.href) | {
            url: $dom + .href,
            title: (.children[-1] | .title // .children[-1].title)
        })) | {
            list: .,
            title: "yummyanime",
            hashkey: "url",
            type: "selectable"
        }'
fi
