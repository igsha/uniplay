#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http htmlq grep >/dev/null

jq -r .url \
    | read -r URL

http GET "$URL" \
    | grep -Po 'window.playerData = \K{.*(?=;</script>)' \
    | mapfile JSON

if [[ "$URL" =~ voice=([0-9]+) ]]; then
    VOICE="${BASH_REMATCH[1]}"
    if [[ "$URL" =~ season=([0-9]+) ]]; then
        SEASON="${BASH_REMATCH[1]}"
        if [[ "$URL" =~ episode=[0-9]+ ]]; then
            echo "kalarona: Extract video from $URL" >&2
            <<< "${JSON[@]}" jq '{
                    url: .config.video,
                    type: "video",
                    title: (.playlist | "\(.current.serialName) - \(.serial.current.season)-\(.serial.current.episode)")
                }'
        else
            echo "kalarona: Select episode from $URL" >&2
            <<< "${JSON[@]}" jq --argjson ss "$SEASON" --argjson vv "$VOICE" --arg url "$URL" '.playlist.serial.list[$ss - 1] | map({
                    url: "\($url)&episode=\(.num)",
                    title: "\(.num)"
                }) | {
                    list: (. | reverse),
                    type: "selectable",
                    title: "kalarona"
                }'
        fi
    else
        echo "kalarona: Select season from $URL" >&2
        <<< "${JSON[@]}" jq --argjson vv "$VOICE" --arg url "$URL" '.playlist.serial.list | keys | map({
                url: "\($url)&season=\(. + 1)",
                title: "\(. + 1)"
            }) | {
                list: (. | reverse),
                type: "selectable",
                title: "kalarona"
            }'
    fi
else
    echo "kalarona: Select voice from $URL" >&2
    <<< "${JSON[@]}" jq --arg url "$URL" '.voices | to_entries | map({
            url: (((select($url | contains("?")) | "&") // "?") as $sep | "\($url)\($sep)voice=\(.key)"),
            title: .value
        }) | {
            list: .,
            type: "selectable",
            title: "kalarona"
        }'
fi
