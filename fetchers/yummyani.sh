#!/usr/bin/env bash
set -ex
shopt -s lastpipe

which jq http awk grep rg > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

[[ "$URL" =~ anime_id=([0-9]+) ]]
ID="${BASH_REMATCH[1]}"

if [[ "$URL" =~ dubbing_code=([^&]+) ]]; then
    DUBBING_CODE="${BASH_REMATCH[1]}"
fi

awk -F/ '{printf "%s//%s\n", $1, $3}' <<< "$URL" \
    | read -r DOMAIN

http GET "$URL" \
    | grep -Po 'src="\K/assets/iframeCVH-[^\.]+\.js' \
    | read -r JS_ASSET

URL="$DOMAIN$JS_ASSET"
echo "yummyani: Extract $URL" >&2
http GET "$URL" \
    | rg --multiline-dotall -UP '"data-aggregator":\s*"([^"]+)".*"data-publisher-id":\s*(\d+)' -or $'$1\n$2' \
    | { read -r AGGR; read -r PUB; }

echo "aggr=$AGGR pub=$PUBLISHER" >&2

export URL="https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=${PUB}&aggr=${AGGR}&id=${ID}"
<<< "${JSON[@]}" jq '.item=env.URL' \
    | "$UNIPLAY" -f cdnvideohub
