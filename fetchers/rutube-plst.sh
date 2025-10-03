#!/usr/bin/env bash
set -e

which http jo jq fzf > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")

[[ "$URL" =~ https?://rutube\.ru/plst/([0-9]+)/? ]]
PLAYLIST="${BASH_REMATCH[1]}"

ID=next
TITLE="https://rutube.ru/api/playlist/custom/$PLAYLIST/videos/?page=1"
while [[ "$ID" == next ]]; do
    URL="$TITLE"
    IFS=$'\t' read -r TITLE ID < <(http GET "$URL" \
        | jq -r '(.results + [.next | select(. != null) | {title: ., id: "next"}]) | .[] | [.title, .id] | @tsv' \
        | fzf)
done

export URL="https://rutube.ru/video/$ID/" TITLE
<<< "${JSON[@]}" jq '.url=env.URL | .title=env.TITLE' | "$UNIPLAY" -f mpv
