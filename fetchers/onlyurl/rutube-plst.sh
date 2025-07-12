#!/usr/bin/env bash
set -e

which http jo jq fzf > /dev/null
if [[ ! "$1" =~ https?://rutube\.ru/plst/([0-9]+)/? ]]; then
    jo result=notmine
    exit 0
fi

PLAYLIST="${BASH_REMATCH[1]}"
ID=next
TITLE="https://rutube.ru/api/playlist/custom/$PLAYLIST/videos/?page=1"
while [[ "$ID" == next ]]; do
    URL="$TITLE"
    IFS=$'\t' read -r TITLE ID < <(http GET "$URL" \
        | jq -r '(.results + [.next | select(. != null) | {title: ., id: "next"}]) | .[] | [.title, .id] | @tsv' \
        | fzf)
done
URL="https://rutube.ru/video/$ID/"

jo result=video "title=$TITLE" "url=$URL"
