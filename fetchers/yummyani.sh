#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http awk grep rg brotli > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .url \
    | read -r URL

DOMAIN="${URL%/${URL#*//*/}}"
if [[ "$URL" =~ dubbing_code=([^\&\?]+)[\&\?]anime_id=([0-9]+)([\&]episode=([0-9]+))? ]]; then
    DUBBIG_CODE="${BASH_REMATCH[1]}"
    ID="${BASH_REMATCH[2]}"
    EPISODE="${BASH_REMATCH[4]}"

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

    echo "yummyani: aggr=$AGGR pub=$PUB id=$ID dubbig_code=$DUBBIG_CODE episode=$EPISODE" >&2
    URL="https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=$PUB&aggr=$AGGR&id=$ID&dubbing_code=$DUBBIG_CODE&episode=$EPISODE"
    echo "yummyani: Extract $URL" >&2
    exec "$UNIPLAY" cdnvideohub "$URL"
elif [[ "$URL" =~ /api/.+dubbing=([^\&]+) ]]; then
    DUBBING="${BASH_REMATCH[1]}"
    echo "yummyani: List series for dubbing $DUBBING in $URL" >&2
    <<< "${JSON[@]}" jq -r '.title2, (.other | @base64d)' \
        | { read -r TITLE; mapfile INNERJSON; }

    if ((${#INNERJSON[@]} == 0)); then
        [[ "$URL" =~ player_id=([^\&]+) ]]
        PLAYER_ID="${BASH_REMATCH[1]}"
        http -F GET "$URL" \
            | jq --arg player_id "$PLAYER_ID" --arg dubbing "$DUBBING" \
                '.response | map(select(.data | .player_id == $player_id and .dubbing == $dubbing))' \
            | mapfile INNERJSON
    fi

    <<< "${INNERJSON[@]}" jq --arg title "$TITLE" 'map({
            url: if (.iframe_url | startswith("http") | not) then "https:" + .iframe_url else .iframe_url end,
            title: "\($title) - \(.number)"
        }) | {
            list: .,
            hashkey: "url",
            type: "selectable",
            title: "yummyani"
        }'
elif [[ "$URL" =~ /api/.+player_id=([^\&]+) ]]; then
    PLAYER_ID="${BASH_REMATCH[1]}"
    echo "yummyani: List dubbers for player $PLAYER_ID in $URL" >&2
    <<< "${JSON[@]}" jq -re '.title2, (.other | @base64d)' \
        | { read -r TITLE; mapfile INNERJSON; }

    if ((${#INNERJSON[@]} == 0)); then
        http -F GET "$URL" \
            | jq --arg player_id "$PLAYER_ID" '.response | map(select(.data.player_id == $player_id))' \
            | mapfile INNERJSON
    fi

    <<< "${INNERJSON[@]}" jq --arg url "$URL" --arg title "$TITLE" 'group_by(.data.dubbing) | map(.[0].data.dubbing as $dubbing | {
            url: $url + "&dubbing=" + $dubbing,
            title: $dubbing,
            other: (. | @base64)
        }) | {
            list: .,
            hashkey: "url",
            type: "selectable",
            title: "yummyani",
            title2: $title
        }'
else
    echo "yummyani: Extract $URL" >&2

    http --follow GET "$URL" \
        | mapfile HTML

    <<< "${HTML[@]}" htmlq title -t \
        | read -r TITLE

    <<< "${HTML[@]}" htmlq 'meta#page_id, meta#page_type' -a content \
        | { read -r PAGEID; read -r PAGETYPE; }

    URL="${DOMAIN}/api/$PAGETYPE/$PAGEID/videos"
    echo "yummyani: List players $URL" >&2

    http --follow GET "$URL" \
        | jq --arg url "$URL" --arg title "$TITLE" -e '.response | group_by(.data.player) | map(.[0].data as $data | {
                url: $url + "?player_id=\($data.player_id)",
                title: $data.player,
                other: (. | @base64)
            }) | {
                list: .,
                hashkey: "url",
                type: "selectable",
                title: "yummyani",
                title2: $title
            }'
fi
