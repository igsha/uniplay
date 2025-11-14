#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq fzf > /dev/null

mapfile -t JSON
jq -r .item <<< "${JSON[@]}" | read -r URL

if [[ "$URL" =~ https?://rutube\.ru/u/[0-9A-Za-z]+/?([a-z]+)?/? ]]; then
    http --follow GET "$URL" | grep -Po '"userChannelId":\K\d+' | head -1 | read -r USERID
    FOLDER=${BASH_REMATCH[1]:-videos}
elif [[ "$URL" =~ https?://rutube\.ru/channel/([0-9]+)/?([a-z]+)?/? ]]; then
    USERID="${BASH_REMATCH[1]}"
    FOLDER=${BASH_REMATCH[2]:-videos}
elif [[ "$URL" =~ /video/([0-9a-z]+)/? ]]; then
    exec "$UNIPLAY" -f rutube-video <<< "${JSON[@]}"
elif [[ "$URL" =~ /plst/([0-9]+)/? ]]; then
    exec "$UNIPLAY" -f rutube-plst <<< "${JSON[@]}"
else
    echo "rutube: Bad url $URL" >&2
    exit 1
fi

echo "rutube: user=$USERID folder=$FOLDER" >&2
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
    echo "rutube: List $URL" >&2
    http GET "$URL" \
        | jq -r '(.results + [.next | select(. != null) | {title: ., id: "next"}]) | .[] | [.title, .id] | @tsv' \
        | fzf \
        | IFS=$'\t' read -r TITLE ID
done

export TITLE URL="$URLBASE/$ID/"
<<< "${JSON[@]}" jq '.item=env.URL | .title=env.TITLE' | "$UNIPLAY" -f mpv
