#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http awk grep rg brotli > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .url \
    | read -r URL

DOMAIN="${URL%/${URL#*//*/}}"
if [[ "$URL" =~ anime_id=([0-9]+) ]]; then
    ID="${BASH_REMATCH[1]}"

    echo "yummyani: CVH fetcher $URL" >&2
    http --follow GET "$URL" \
        | htmlq 'script[type="module"]' -a src \
        | xargs printf "%s%s\n" "$DOMAIN" \
        | read -r URL

    echo "yummyani: Extract CVH asset $URL" >&2
    http --follow GET "$URL" \
        | brotli -d \
        | rg --multiline-dotall -UP '"data-aggregator":\s*"([^"]+)".*"data-publisher-id":\s*(\d+)' -or $'$1\n$2' \
        | { read -r AGGR; read -r PUB; }

    echo "yummyani: aggr=$AGGR pub=$PUB id=$ID" >&2
    URL="https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=${PUB}&aggr=${AGGR}&id=${ID}"
    echo "yummyani: Extract $URL" >&2
    exec "$UNIPLAY" cdnvideohub "$URL"
else
    echo "yummyani: Extract $URL" >&2

    http --follow GET "$URL" \
        | htmlq 'meta#page_id, meta#page_type' -a content \
        | { read -r PAGEID; read -r PAGETYPE; }

    URL="${DOMAIN}/api/$PAGETYPE/$PAGEID/videos"
    echo "yummyani: List players $URL" >&2

    http --follow GET "$URL" \
        | jq '.response | group_by(.data.player)
                | map(.[0] | {
                    url: "https:" + (.iframe_url | if contains("kodik") then sub("\\?.*"; "") end),
                    title: .data.player})
                | {list: ., hashkey: "url", type: "selectable", title: "yummyani"}'
fi
