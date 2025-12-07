#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http fzf > /dev/null

mapfile -t ORIGJSON
jq -r .item <<< "${ORIGJSON[@]}" \
    | read -r URL

echo "cdnvideohub: Extract $URL" >&2
http GET "$URL" \
    | mapfile JSON

<<< "${JSON[@]}" jq -r '.titleName[0:100] + if (.titleName | length) > 100 then "..." else "" end' \
    | read -r TITLE

<<< "${JSON[@]}" jq '.items
    | group_by(.voiceStudio)
    | map({name:
        (.[0].voiceStudio | select(. | length == 0) |= "empty"),
        count: length,
        series: [.[] | pick(.season, .episode, .vkId, .cvhId)]
    })' \
    | mapfile JSON

if [[ "$URL" =~ dubbing_code=([^&]+) ]]; then
    VOICE="${BASH_REMATCH[1]/+/ }"
else
    echo "cdnvideohub: Select voice (series count, voice name)" >&2
    <<< "${JSON[@]}" jq -r '.[] | [.count, .name] | @tsv' \
        | fzf -d $'\t' --accept-nth 2 \
        | read -r VOICE
fi

export VOICE
echo "cdnvideohub: Select episode [$VOICE]" >&2
<<< "${JSON[@]}" jq -r '.[] | select(.name == env.VOICE) | .name as $n | .series[] | [$n, "\(.season)-\(.episode)", .vkId] | @tsv' \
    | fzf -d $'\t' --accept-nth 2,3 \
    | IFS=$'\t' read -r STITLE VKID

echo "cdnvideohub: Extract https://plapi.cdnvideohub.com/api/v1/player/sv/video/$VKID" >&2
http GET "https://plapi.cdnvideohub.com/api/v1/player/sv/video/$VKID" \
    | jq -r '.sources
            | with_entries(select(.value != ""))
            | (.mpeg4kUrl // .mpeg2kUrl // .mpegQhdUrl // .mpegFullHdUrl // .mpegHighUrl // .hlsUrl // .dashUrl)' \
    | read -r URL

export URL TITLE="$TITLE - $STITLE"
<<< "${ORIGJSON[@]}" jq '.item=env.URL | .title=env.TITLE' \
    | "$UNIPLAY" -f mpv
