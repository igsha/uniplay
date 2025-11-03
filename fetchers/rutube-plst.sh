#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http fzf > /dev/null

mapfile -t JSON
jq -r .url <<< "${JSON[@]}" | read -r URL

[[ "$URL" =~ [^/]+://[^/]+/[^/]+/([0-9]+)/? ]]
ID=next
TITLE="https://rutube.ru/api/playlist/custom/${BASH_REMATCH[1]}/videos?page=1"
while [[ "$ID" == next ]]; do
    URL="$TITLE"
    echo "rutube-plst: List $URL" >&2
    http GET "$URL" \
        | jq -r '(.results + [.next | select(. != null) | {title: ., id: "next"}]) | .[] | [.title, .id] | @tsv' \
        | fzf \
        | IFS=$'\t' read -r TITLE ID
done

export URL="https://rutube.ru/video/$ID/"
echo "rutube-plst: Extract $URL"
<<< "${JSON[@]}" \
    jq '.url=env.URL' \
    | "$UNIPLAY" -f rutube-video
