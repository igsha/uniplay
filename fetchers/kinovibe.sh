#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http pup grep >/dev/null

jq -r '.url' \
    | read -r URL

if [[ "$URL" =~ /player/ ]]; then
    http GET "$URL" \
        | jq '.playlist | map({
                url: .file,
                title: .comment
            }) | {
                list: .,
                hashkey: "url",
                title: "kinovibe",
                type: "selectable",
                pipeline: "video",
                fetcher: "mpv"
            }'
else
    http GET "$URL" \
        | pup 'script:contains("Playerjs") text{}' \
        | grep -Po 'file:"\K[^"]+' \
        | jq -R '{url: .}'
fi
