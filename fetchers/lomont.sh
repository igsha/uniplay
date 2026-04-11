#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq > /dev/null

jq -r .url \
    | read -r URL

echo "lomont: Download $URL" >&2
http GET "$URL" \
    | htmlq -t "#inputData" \
    | mapfile JSON

# rearrange
<<< "${JSON[@]}" jq 'to_entries | map(.value | to_entries | map(.value) | flatten) | flatten | group_by(.voice_id)' \
    | mapfile JSON

<<< "${JSON[@]}" jq '{list: map(.[-1] | {url: .voice_id, title: "\(.voice_name) \(.season)-\(.episode)"}), title: "lomont", type: "selectable"}'

echo "lomont: Selected voice id $VOICE_ID" >&2
<<< "${JSON[@]}" jq --arg vid "$VOICE_ID" --arg base "https://lomont.site/player/responce.php?video_id=" \
    '.[] | select(.[0].voice_id == $vid) |
    {items: (map({item: "\($base)\(.video_id)", name: "\(.season)-\(.episode)"}) | reverse), title: "lomont"}' \
    | "$UNIPLAY" -f marksel \
    | jq -r '.item, .title' \
    | { read -r URL; read -r TITLE; }

echo "lomont: Download seria $URL" >&2
export TITLE
http GET "$URL" \
    | jq '{item: .src, title: env.TITLE} + ({subsurl: .subtitles.ru?} // {})' \
    | "$UNIPLAY" -f mpv
