#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http htmlq >/dev/null

jq -r .url \
    | read -r URL

http GET "$URL" \
    | mapfile HTML

parsedata() {
    htmlq '#inputData' -t \
        | jq 'to_entries | map(.value | to_entries | map(.value)) | flatten'
}

if [[ "$URL" =~ voice=([0-9]+) ]]; then
    VOICE="${BASH_REMATCH[1]}"
    if [[ "$URL" =~ season=([0-9]+) ]]; then
        SEASON="${BASH_REMATCH[1]}"
        if [[ "$URL" =~ episode=[0-9]+ ]]; then
            echo "kalarona: Extract video from $URL" >&2
            <<< "${HTML[@]}" htmlq .flowplayer -a data-config \
                | jq '{
                    url: .hls,
                    type: "video",
                    title: "kalarona"
                }'
        else
            echo "kalarona: Select episode from $URL" >&2
            <<< "${HTML[@]}" parsedata \
                | jq --argjson ss "$SEASON" --argjson vv "$VOICE" --arg url "$URL" 'map(select(.season == $ss and .voice_id == $vv) | {
                        url: "\($url)&episode=\(.episode)",
                        title: .episode
                    }) | {
                        list: .,
                        type: "selectable",
                        title: "kalarona"
                    }'
        fi
    else
        echo "kalarona: Select season from $URL" >&2
        <<< "${HTML[@]}" parsedata \
            | jq --argjson vv "$VOICE" --arg url "$URL" 'map(select(.voice_id == $vv)) | unique_by(.season) | map({
                    url: "\($url)&season=\(.season)",
                    title: .season
                }) | {
                    list: .,
                    type: "selectable",
                    title: "kalarona"
                }'
    fi
else
    echo "kalarona: Select voice from $URL" >&2
    <<< "${HTML[@]}" parsedata \
        | jq --arg url "$URL" 'map({voice_name, voice_id}) | unique_by(.voice_id) | map({
                url: "\($url)&voice=\(.voice_id)",
                title: .voice_name
            }) | {
                list: .,
                type: "selectable",
                title: "kalarona"
            }'
fi
