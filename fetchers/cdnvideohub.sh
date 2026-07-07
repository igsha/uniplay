#!/usr/bin/env bash
# Input: https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=<pub>&aggr=<aggr>&id=<id>[&dubbing_code=<dubbing>][&episode=<ep>]
# Input: https://plapi.cdnvideohub.com/api/v1/player/sv/video/<vkId>
# Output:
#   * ask for translation (if no `dubbing_code`),
#   * ask for seria (if no `vkId` or `ep`)
set -e
shopt -s lastpipe

which jq http tee >/dev/null

mapfile JSON
<<< "${JSON[@]}" jq -r .url \
    | read -r URL

if [[ "$URL" =~ /video/[0-9]+ ]]; then
    echo "cdnvideohub: Extract video from $URL" >&2
    <<< "${JSON[@]}" jq -r .title \
        | read -r TITLE

    http GET "$URL" \
        | jq '.sources | to_entries | map(select(.value != ""))
            | sort_by(.key as $key
                | ["mpeg4kUrl", "mpeg2kUrl", "mpegFullHdUrl", "mpegHighUrl", "hlsUrl", "dashUrl"]
                | index($key) // 77)' \
        | tee >(jq -r '.[] | "cdnvideohub: [\(.key)] \(.value)"' >&2) \
        | jq --arg title "$TITLE" '{url: .[0].value, title: $title, type: "video"}'
else
    echo "cdnvideohub: Extract $URL" >&2
    http GET "$URL" \
        | mapfile JSON

    if [[ "$URL" =~ dubbing_code=([^&]+) ]]; then
        VOICE="${BASH_REMATCH[1]/+/ }"
        <<< "${JSON[@]}" jq -r '.titleName[0:100] + if (.titleName | length) > 100 then "..." else "" end' \
            | read -r TITLE

        if [[ "$URL" =~ episode=([0-9]+) ]]; then
            EPISODE="${BASH_REMATCH[1]}"
            echo "cdnvideohub: Convert video [$VOICE]+$EPISODE" >&2
            <<< "${JSON[@]}" jq --arg voice "$VOICE" --arg title "$TITLE" --argjson ep "$EPISODE" \
                '.items | map(select((.voiceStudio // .voiceType) == $voice and .episode == $ep))[0] | {
                    url: "https://plapi.cdnvideohub.com/api/v1/player/sv/video/\(.vkId)",
                    title: "\($title) \(.season)-\(.episode)"
                }'
        else
            echo "cdnvideohub: List episodes [$VOICE]" >&2
            <<< "${JSON[@]}" jq --arg voice "$VOICE" --arg title "$TITLE" \
                    '.items | map(select((.voiceStudio // .voiceType) == $voice) | {
                        url: "https://plapi.cdnvideohub.com/api/v1/player/sv/video/\(.vkId)",
                        title: "\($title) \(.season)-\(.episode)"
                    }) | reverse | {
                        list: .,
                        title: "cdnvideohub",
                        hashkey: "url",
                        type: "selectable"}'
        fi
    else
        echo "cdnvideohub: List voices (voice name, series count)" >&2
        <<< "${JSON[@]}" jq --arg url "$URL" \
                '.items | group_by(.voiceStudio) | map((.[0] | .voiceStudio // .voiceType) as $name | {
                    title: $name,
                    count: length,
                    url: "\($url)&dubbing_code=\($name)"})
                | {list: ., title: "cdnvideohub", hashkey: "url", type: "selectable"}'
    fi
fi
