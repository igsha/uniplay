#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http htmlq xq >/dev/null

jq -r '.url, (.url | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ /player/videos/[0-9]+ ]]; then
    echo "animego: List translations $URL" >&2
    http GET "$URL" "referer:$DOMAIN" X-Requested-With:XMLHttpRequest \
        | jq -r .data.content \
        | htmlq '*[data-player]' \
        | htmlq \
        | xq '.html.body.button | if type == "object" then [.] else . end | map({
                url: "https:" + .["@data-player"],
                title: "\(.["@data-provider-title"]) \(.["@data-translation-title"])"
            }) | {
                list: .,
                hashkey: "url",
                type: "selectable",
                title: "animego"
            }'
elif [[ "$URL" =~ /[^/]+-([0-9]+) ]]; then
    ANIMEID="${BASH_REMATCH[1]}"

    SCHEDULE="$DOMAIN/anime/$ANIMEID/9999999/schedule/load"
    echo "animego: List episodes $SCHEDULE" >&2
    http GET "$SCHEDULE" "referer:$DOMAIN" X-Requested-With:XMLHttpRequest \
        | jq -r .data.content \
        | htmlq  --remove-nodes button,span \
        | htmlq \
        | xq --arg url "$URL" --arg dom "$DOMAIN" '.html.body.div | to_entries | group_by(.key / 4 | trunc) | map(.[2].value + .[3].value | select(.["#text"]? | not) | {
                url: "\($dom)/player/videos/\(.["@data-episode"])",
                title: .["@data-number"]
            }) | {
                list: .,
                hashkey: "url",
                type: "selectable",
                title: "animego"
            }'
elif [[ "$URL" =~ /cdn-iframe/[0-9]+ ]]; then
    echo "animego: Convert $URL to CVH url" >&2
    http GET "$URL" \
        | htmlq video-player \
        | xq '.["video-player"] | {pub: .["@data-publisher-id"], aggr: .["@data-aggregator"], id: .["@data-title-id"], dub: .["@priority-voice"], ep: .["@episode"]} | {
            url: "https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=\(.pub)&aggr=\(.aggr)&id=\(.id)&dubbing_code=\(.dub)&episode=\(.ep)",
            title: "\(.["@priority-voice"]) - \(.["@episode"])"
        }'
else
    echo "animego: Unknown url $URL" >&2
    exit 1
fi
