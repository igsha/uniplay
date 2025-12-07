#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http awk grep rg > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

DOMAIN="${URL%/${URL#*//*/}}"
if [[ "$URL" =~ anime_id=([0-9]+) ]]; then
    ID="${BASH_REMATCH[1]}"

    echo "yummyani: CVH fetcher $URL" >&2
    http GET "$URL" \
        | htmlq 'script[type="module"]' -a src \
        | xargs printf "%s%s\n" "$DOMAIN" \
        | read -r URL

    echo "yummyani: Extract CVH asset $URL" >&2
    http GET "$URL" \
        | rg --multiline-dotall -UP '"data-aggregator":\s*"([^"]+)".*"data-publisher-id":\s*(\d+)' -or $'$1\n$2' \
        | { read -r AGGR; read -r PUB; }

    echo "yummyani: aggr=$AGGR pub=$PUB id=$ID" >&2
    URL="https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=${PUB}&aggr=${AGGR}&id=${ID}"
    echo "yummyani: Extract $URL" >&2
    jo result=url item="$URL" \
        | exec "$UNIPLAY" -f cdnvideohub
else
    echo "yummyani: List fetcher $URL" >&2

    http GET "$URL" \
        | htmlq 'meta#page_id, meta#page_type' -a content \
        | { read -r PAGEID; read -r PAGETYPE; }

    URL="${DOMAIN}/api/$PAGETYPE/$PAGEID/videos"
    echo "yummyani: Extract $URL" >&2

    http GET "$URL" \
        | jq '.response | {items: map({item: "https:" + .iframe_url, name: "\(.data.dubbing) \(.data.player) \(.number)"})}' \
        | "$UNIPLAY" -f selector \
        | exec "$UNIPLAY"
fi
