#!/usr/bin/env bash
# Input: https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=<pub>&aggr=<aggr>&id=<id>[&dubbing_code=<dubbing>]
# Input: https://plapi.cdnvideohub.com/api/v1/player/sv/video/<vkId>
# Output:
#   * ask for translation (if no `dubbing_code`),
#   * ask for seria (if no `vkId`)
set -e
shopt -s lastpipe

which jq http tee > /dev/null

mapfile JSON
<<< "${JSON[@]}" jq -r .item \
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
        | jq --arg title "$TITLE" '{item: .[0].value, title: $title}' \
        | exec "$UNIPLAY" -f mpv
else
    echo "cdnvideohub: Extract $URL" >&2
    http GET "$URL" \
        | mapfile JSON

    if [[ "$URL" =~ dubbing_code=([^&]+) ]]; then
        VOICE="${BASH_REMATCH[1]/+/ }"
        <<< "${JSON[@]}" jq -r '.titleName[0:100] + if (.titleName | length) > 100 then "..." else "" end' \
            | read -r TITLE

        echo "cdnvideohub: List episodes [$VOICE]" >&2
        <<< "${JSON[@]}" jq --arg voice "$VOICE" \
                '.items | map(select(.voiceStudio == $voice)
                     | {item: "https://plapi.cdnvideohub.com/api/v1/player/sv/video/\(.vkId)",
                        name: "\(.season)-\(.episode)"}) | reverse
                     | {items: ., title: "cdnvideohub"}' \
            | "$UNIPLAY" -f marksel \
            | jq --arg title "$TITLE" '{item, title: "\($title) - \(.title)"}' \
            | exec "$UNIPLAY" -f cdnvideohub
    else
        echo "cdnvideohub: List voices (voice name, series count)" >&2
        <<< "${JSON[@]}" jq --arg url "$URL" \
                '.items | group_by(.voiceStudio) | map(.[0].voiceStudio as $name | {
                    name: $name,
                    count: length,
                    item: "\($url)&dubbing_code=\($name)"})
                | {items: ., title: "cdnvideohub"}' \
            | "$UNIPLAY" -f selector \
            | exec "$UNIPLAY" -f cdnvideohub
    fi
fi
