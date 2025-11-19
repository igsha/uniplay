#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq jo > /dev/null

mapfile -t JSON
jq -r .item <<< "${JSON[@]}" | read -r URL

if [[ "$URL" =~ /video/([0-9a-z]+)/? ]]; then
    <<< "${JSON[@]}" "$UNIPLAY" -f rutube-video \
        | "$UNIPLAY" -f mpv
    exit $?
elif [[ "$URL" =~ /plst/([0-9]+)/? ]]; then
    jo result=url item="https://rutube.ru/api/playlist/custom/${BASH_REMATCH[1]}/videos" \
        | "$UNIPLAY" -f rutube-list \
        | "$UNIPLAY" -f rutube
    exit $?
fi

if [[ "$URL" =~ https?://rutube\.ru/u/[0-9A-Za-z]+/?([a-z]+)?/? ]]; then
    http --follow GET "$URL" | grep -Po '"userChannelId":\K\d+' | head -1 | read -r USERID
    FOLDER=${BASH_REMATCH[1]:-videos}
elif [[ "$URL" =~ https?://rutube\.ru/channel/([0-9]+)/?([a-z]+)?/? ]]; then
    USERID="${BASH_REMATCH[1]}"
    FOLDER=${BASH_REMATCH[2]:-videos}
fi

echo "rutube: user=$USERID folder=$FOLDER" >&2
if [[ "$FOLDER" == videos ]]; then
    URL="https://rutube.ru/api/video/person/$USERID/?origin__type=rtb,rst,ifrm,rspa"
elif [[ "$FOLDER" == playlists ]]; then
    URL="https://rutube.ru/api/playlist/user/$USERID"
elif [[ "$FOLDER" == shorts ]]; then
    URL="https://rutube.ru/api/video/person/$USERID/?origin__type=rshorts"
fi

jo result=url item="$URL" \
    | "$UNIPLAY" -f rutube-list \
    | "$UNIPLAY" -f rutube
