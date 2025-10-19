#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http fzf > /dev/null

mapfile -t ORIGJSON
jq -r .url <<< "${ORIGJSON[@]}" \
    | read -r URL

http GET "$URL" \
    | mapfile -t JSON

jq -r .titleName <<< "${JSON[@]}" \
    | read -r TITLE

jq '.items
    | group_by(.voiceStudio)
    | map({name:
        (.[0].voiceStudio),
        count: length,
        series: [.[] | pick(.season, .episode, .vkId, .cvhId)]
    })' <<< "${JSON[@]}" \
    | mapfile -t JSON

jq -r '.[] | [.count, .name] | @tsv' <<< "${JSON[@]}" \
    | fzf --accept-nth 2 \
    | IFS=$'\t' read -r VOICE

export VOICE
jq -r '.[] | select(.name == env.VOICE) | .name as $n | .series[] | [$n, "\(.season)-\(.episode)", .vkId] | @tsv' <<< "${JSON[@]}" \
    | fzf --accept-nth 2,3 \
    | IFS=$'\t' read -r STITLE VKID

echo "cdnvideohub: Extract https://plapi.cdnvideohub.com/api/v1/player/sv/video/$VKID" >&2
http GET "https://plapi.cdnvideohub.com/api/v1/player/sv/video/$VKID" \
    | jq -r '.sources
            | with_entries(select(.value != ""))
            | (.mpeg4kUrl // .mpeg2kUrl // .mpegQhdUrl // .mpegFullHdUrl // .mpegHighUrl // .hlsUrl // .dashUrl)' \
    | read -r URL

TITLE="$TITLE - $STITLE"
export URL TITLE
<<< "${ORIGJSON[@]}" jq '.url=env.URL | .title=env.TITLE' \
    | "$UNIPLAY" -f mpv
