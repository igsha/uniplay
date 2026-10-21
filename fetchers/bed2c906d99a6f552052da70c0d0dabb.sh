#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq grep tee >/dev/null

jq -r '.url, (.url | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

http -F GET "$URL" \
    | mapfile HTML

if [[ "$URL" =~ viewkey=[0-9a-z]+ ]]; then
    echo "bed2c906d99a6f552052da70c0d0dabb: Extract video from $URL" >&2
    <<< "${HTML[@]}" pup 'script:contains("flashvars_")' \
        | grep -Po 'var flashvars_[^ ]+\s*=\s*\K{.*}(?=;)' \
        | jq '.mediaDefinitions |= (sort_by(.width * .height) | reverse)' \
        | tee >(jq -r '.mediaDefinitions[] | "bed2c906d99a6f552052da70c0d0dabb: \(.width)x\(.height) \(.format) \(.videoUrl)"' >&2) \
        | jq --arg dom "$DOMAIN" '.video_title as $title | .mediaDefinitions | map(select(.format == "hls")) | first | .videoUrl | {
                url: .,
                title: $title,
                type: "video",
                headers: {
                    origin: $dom,
                    referer: $dom
                },
                parallel: 1
            }'
elif [[ "$URL" =~ /video/?\?c=[0-9]+ || "$URL" =~ /channels || "$URL" =~ /video/search ]]; then
    echo "bed2c906d99a6f552052da70c0d0dabb: Extract next url from $URL" >&2
    <<< "${HTML[@]}" pup -p '.page_next a attr{href}' \
        | read -r NEXTURL

    echo "bed2c906d99a6f552052da70c0d0dabb: List views for $URL" >&2
    <<< "${HTML[@]}" pup 'ul[id^="video"] .pcVideoListItem .phimage a json{}' \
        | jq --arg dom "$DOMAIN" --arg nexturl "$NEXTURL" 'map({
                url: $dom + .href,
                title
            }) + [{url: $dom + $nexturl, title: "###next###"}] | {
                list: .,
                title: "bed2c906d99a6f552052da70c0d0dabb",
                hashkey: "url",
                type: "selectable"
            }'
else
    echo "bed2c906d99a6f552052da70c0d0dabb: Unsupported url $URL" >&2
    exit 1
fi
