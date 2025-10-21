#!/usr/bin/env bash
set -e

which http jq fzf > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")

if [[ "$URL" =~ https?://rutube\.ru/u/[0-9A-Za-z]+/?([a-z]+)?/? ]]; then
    read -r USERID < <(http --follow GET "$URL" | grep -Po '"userChannelId":\K\d+' | head -1)
    FOLDER=${BASH_REMATCH[1]:-videos}
else
    [[ "$URL" =~ https?://rutube\.ru/channel/([0-9]+)/?([a-z]+)?/? ]] || { echo "Bad url $URL"; exit 1; }
    USERID="${BASH_REMATCH[1]}"
    FOLDER=${BASH_REMATCH[2]:-videos}
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
    IFS=$'\t' read -r TITLE ID < <(http GET "$URL" \
        | jq -r '(.results + [.next | select(. != null) | {title: ., id: "next"}]) | .[] | [.title, .id] | @tsv' \
        | fzf)
done

export TITLE URL="$URLBASE/$ID/"
<<< "${JSON[@]}" jq '.url=env.URL | .title=env.TITLE' | "$UNIPLAY" -f mpv
