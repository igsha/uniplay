#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

jq -r '.url, (.url | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ episode=list && "$URL" =~ animego_id=([0-9]+) ]]; then
    ANIMEID="${BASH_REMATCH[1]}"
    SCHEDULE="https://animego.me/anime/${ANIMEID}/9999999/schedule/load"
    echo "aniboom: List episodes $SCHEDULE" >&2

    http GET "$SCHEDULE" referer:https://animego.me X-Requested-With:XMLHttpRequest \
        | jq -r .data.content \
        | htmlq  --remove-nodes button,span \
        | htmlq \
        | xq --arg url "$URL" '.html.body.div | to_entries | group_by(.key / 4 | trunc) | map(.[2].value + .[3].value | select(.["#text"]? | not) | .["@data-number"] | {
                url: (. as $num | $url | sub("episode=list"; "episode=\($num)")),
                title: .
            }) | {
                list: .,
                hashkey: "url",
                type: "selectable",
                title: "aniboom"
            }'
elif [[ "$URL" =~ episode=([0-9]+) ]]; then
    EPISODE="${BASH_REMATCH[1]}"
    echo "aniboom: Extract episode $EPISODE $URL" >&2
    http GET "$URL" "referer:$DOMAIN" \
        | mapfile HTML

    <<< "${HTML[@]}" htmlq title \
        | xq -r .title \
        | read -r TITLE

    <<< "${HTML[@]}" htmlq video -a data-parameters \
        | jq --arg title "$TITLE" --arg num "$EPISODE" '.dash | fromjson | .src | {
            url: .,
            type: "video",
            title: "\($title) - \($num)"
        }'
fi
