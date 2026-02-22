#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http iconv htmlq tee awk jo > /dev/null

jq -r '.item' \
    | read -r URL

APIURL="https://vk.com/al_video.php"
if [[ "$URL" =~ /video(-[0-9]+_[0-9]+) ]]; then
    VIDEOID="${BASH_REMATCH[1]}"
    echo "vkvideo: Get info $VIDEOID from $APIURL for $URL" >&2
    http --ignore-stdin -f POST "$APIURL" act=show "video=$VIDEOID" al=1 "Referer:$APIURL" X-Requested-With:XMLHttpRequest \
        | iconv -f cp1251 \
        | jq -r '.payload[1] | .[0], .[1]' \
        | { read -r TITLE; mapfile HTML; }

    echo "vkvideo: Take the second video" >&2
    <<< "${HTML[@]}" htmlq source -a src \
        | tee >(awk '{print "vkvideo:", $0}' >&2) \
        | jo -a \
        | jq --arg title "$TITLE" --arg url "$URL" '{item: .[1], title: $title, replacepath: $url}' \
        | "$UNIPLAY" -f mpv
elif [[ "$URL" =~ /playlist/(-[0-9]+)_([0-9]+) ]]; then
    OID="${BASH_REMATCH[1]}"
    PLSTID="playlist_${BASH_REMATCH[2]}"
    echo "vkvideo: List playlist $PLSTID of $OID from $APIURL for $URL" >&2
    http --ignore-stdin -f POST "$APIURL" act=load_videos_silent offset=0 "oid=$OID" al=1 "section=$PLSTID" "Referer:$APIURL" X-Requested-With:XMLHttpRequest \
        | iconv -f cp1251 \
        | jq --arg id "$PLSTID" -r '.payload[1][0].[$id].list
            | map({item: .[] | select(type == "string" and contains("/video-")) | "https://vkvideo.ru" + ., name: .[3]})
            | {items: . | reverse, title: "vkvideo"}' \
        | "$UNIPLAY" -f marksel \
        | exec "$UNIPLAY" -f vkvideo
else
    echo "vkvideo: Unsupported url $URL" >&2
    exit 1
fi
