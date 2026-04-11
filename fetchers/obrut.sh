#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http grep sed base64 tee rg > /dev/null

mapfile JSON
if <<< "${JSON[@]}" jq -r '(.content // empty), .referer, .useragent' \
    | { read -r CONTENT; read -r REFERER; read -r UA; }; then
    echo "obrut: Parse content" >&2
    <<< "$CONTENT" tr , '\n' \
        | rg '\[([^]]+)\]([^ ]+)' -or '{"key": "$1", "value": "$2"}' \
        | jq -s 'sort_by(.key | (match("(\\d+)p") | .captures[0].string | tonumber) // 0) | reverse' \
        | tee >(jq -r '.[] | "obrut: [\(.key)] \(.value)"' >&2) \
        | jq -r '.[0].value' \
        | read -r URL

    echo "obrut: Get the final $URL" >&2
    http -Fhv GET "$URL" "referer:$REFERER" "user-agent:$UA" \
        | grep -Po "Location:[ ]*\K.+m3u8" \
        | tail -1 \
        | read -r URL

    echo "obrut: Final url $URL" >&2
    <<< "${JSON[@]}" jq --arg url "$URL" 'del(.content,.useragent,.referer) | .type=video | .url=$url'
else
    <<< "${JSON[@]}" jq -r '.url, (.url | split("/")[0:3] | join("/")), (.useragent // empty)' \
        | {
            read -r URL
            read -r DOMAIN
            if ! read -r UA; then
                "$UNIPLAY" random-user-agent "$URL" \
                    | jq -r .useragent \
                    | read -r UA
            fi
        }

    echo "obrut: Extract $URL with ref=$DOMAIN, ua=$UA" >&2
    http GET "$URL" "referer:$DOMAIN" "user-agent:$UA" \
        | grep -oP 'new Player\("\K[^"]+' \
        | sed 's;//[A-Za-z0-9]\+=;;g' \
        | read ENCRYPTED

    <<< "ey${ENCRYPTED#*ey}" base64 -d \
        | mapfile JSON

    if <<< "${JSON[@]}" jq -e '.file[0] | has("folder")' > /dev/null; then
        echo "obrut: Parse serial" >&2
        <<< "${JSON[@]}" jq '.file | map(
                .title as $season | .folder | map(
                    .title as $episode | .folder | map(
                        . + {season: $season, episode: $episode})))
                | flatten | map(pick(.title,.t1,.file,.season,.episode))' \
            | mapfile JSON
    else
        echo "obrut: Parse movie" >&2
        <<< "${JSON[@]}" jq '.file | map(pick(.title,.t1,.file) + {season: 0, episode: 0})' \
            | mapfile JSON
    fi

    if [[ "$URL" =~ dubbing=([^?&]+) ]]; then
        DUB="${BASH_REMATCH[1]}"

        echo "obrut: List series for [$DUB]" >&2
        <<< "${JSON[@]}" jq --arg dub "${BASH_REMATCH[1]}" --arg ua "$UA" --arg dom "$DOMAIN" 'map(select(.title == $dub)) | {
                list: map("\(.season)-\(.episode)" as $se | {
                    content: .file,
                    title: ("\($dub) \($se)" as $sup | .t1 | select(. != "") // $sup)}) | reverse,
                haskey: "title",
                type: "selectable",
                fetcher: "obrut",
                useragent: $ua,
                referer: $dom,
                title: "obrut"}'
    else
        echo "obrut: List dubbers" >&2
        <<< "${JSON[@]}" jq --arg url "$URL" 'group_by(.title) | map(.[0].title as $name | {
                    title: $name,
                    count: length,
                    url: "\($url)?dubbing=\($name)"})
                | {list: ., title: "obrut", hashkey: "url", type: "selectable"}'
    fi
fi
