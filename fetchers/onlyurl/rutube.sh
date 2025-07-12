#!/usr/bin/env bash
set -e

which http jo jq fzf > /dev/null
if [[ ! "$1" =~ https?://rutube\.ru/channel/([0-9]+)/?([a-z]+)?/? ]]; then
    jo result=notmine
    exit 0
fi

USERID="${BASH_REMATCH[1]}"
FOLDER=${BASH_REMATCH[2]:-videos}
if [[ "$FOLDER" == videos ]]; then
    FIRSTURL="https://rutube.ru/api/video/person/$USERID/?origin__type=rtb,rst,ifrm,rspa&page=1"
    URLBASE="https://rutube.ru/video"
elif [[ "$FOLDER" == playlists ]]; then
    FIRSTURL="https://rutube.ru/api/playlist/user/$USERID/?page=1"
    URLBASE="https://rutube.ru/plst"
elif [[ "$FOLDER" == shorts ]]; then
    FIRSTURL="https://rutube.ru/api/video/person/$USERID/?origin__type=rshorts&page=1"
    URLBASE="https://rutube.ru/shorts"
fi

ID=next
TITLE="$FIRSTURL"
while [[ "$ID" == next ]]; do
    URL="$TITLE"
    IFS=$'\t' read -r TITLE ID < <(http GET "$URL" \
        | jq -r '(.results + [.next | select(. != null) | {title: ., id: "next"}]) | .[] | [.title, .id] | @tsv' \
        | fzf)
done
URL="$URLBASE/$ID/"

jo result=video "title=$TITLE" "url=$URL"
