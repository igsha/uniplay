#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http grep pup >/dev/null

mapfile JSON
<<< "${JSON[@]}" jq -r .url \
    | read -r URL

if [[ "$URL" =~ /hls/ ]]; then
    echo "dreamerscast: Play video $URL" >&2
    <<< "${JSON[@]}" jq '.type="video"'
elif [[ "$URL" =~ /home/ ]]; then
    echo "dreamerscast: List episodes $URL" >&2
    http GET "$URL" \
        | pup 'script:contains("Playerjs") text{}' \
        | grep -Po 'let list = atob\("\K[^"]+' \
        | jq -R '@base64d | split("||||") | to_entries | map({
                url: .value,
                title: "Episode #\(.key + 1)"
            }) | {
                list: (. | reverse),
                title: "dreamerscast",
                hashkey: "url",
                type: "selectable"
            }'
else
    echo "dreamerscast: Unsupported url $URL" >&2
    exit 1
fi
