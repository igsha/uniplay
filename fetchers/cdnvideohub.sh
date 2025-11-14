#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http fzf > /dev/null

mapfile -t ORIGJSON
jq -r .item <<< "${ORIGJSON[@]}" \
    | read -r URL

http GET "$URL" \
    | mapfile -t JSON

jq -r '.titleName[0:100] + if (.titleName | length) > 100 then "..." else "" end' <<< "${JSON[@]}" \
    | read -r TITLE

jq '.items
    | group_by(.voiceStudio)
    | map({name:
        (.[0].voiceStudio),
        count: length,
        series: [.[] | pick(.season, .episode, .vkId, .cvhId)]
    })' <<< "${JSON[@]}" \
    | mapfile -t JSON

if [[ "$URL" =~ dubbing_code=([^&]+) ]]; then
    VOICE="${BASH_REMATCH[1]/+/ }"
else
    jq -r '.[] | [.count, .name] | @tsv' <<< "${JSON[@]}" \
        | fzf -d $'\t' --accept-nth 2 \
        | read -r VOICE
fi

export VOICE
jq -r '.[] | select(.name == env.VOICE) | .name as $n | .series[] | [$n, "\(.season)-\(.episode)", .vkId] | @tsv' <<< "${JSON[@]}" \
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
