#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http iconv htmlq tee awk jo > /dev/null

jq -r .url \
    | read -r URL

APIURL="https://vkvideo.ru/al_video.php"
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
        | jq --arg title "$TITLE" --arg url "$URL" '{url: .[1], title: $title, replacepath: $url, type: "video"}'
elif [[ "$URL" =~ /playlist/(-[0-9]+)_([0-9]+) ]]; then
    OID="${BASH_REMATCH[1]}"
    PLSTID="playlist_${BASH_REMATCH[2]}"
    echo "vkvideo: List playlist $PLSTID of $OID from $APIURL for $URL" >&2
    http --ignore-stdin -f POST "$APIURL" act=load_videos_silent offset=0 "oid=$OID" al=1 "section=$PLSTID" "Referer:$APIURL" X-Requested-With:XMLHttpRequest \
        | iconv -f cp1251 \
        | jq --arg id "$PLSTID" -r '.payload[1][0].[$id].list
            | map({url: .[] | select(type == "string" and contains("/video-")) | "https://vkvideo.ru" + ., title: .[3]})
            | {list: . | reverse, title: "vkvideo", type: "selectable", hashkey: "url"}'
elif [[ "$URL" =~ /@[^/]+/clips ]]; then
    CLIENTID=52461373
    echo "vkvideo: Get anonym_token" >&2
    http --ignore-stdin -f POST "https://login.vk.com/?act=get_anonym_token" \
            client_secret=o557NLIkAErNhakXrQ7A \
            client_id="$CLIENTID" \
            scopes=audio_anonymous,video_anonymous,photos_anonymous,profile_anonymous \
            isApiOauthAnonymEnabled=false \
            version=1 \
            app_id=6287487 \
        | jq -r .data.access_token \
        | read -r ACCESS_TOKEN

    http --ignore-stdin -f POST "https://api.vkvideo.ru/method/catalog.getVideo?v=5.275&client_id=$CLIENTID" \
            "url=$URL" \
            need_blocks=1 \
            "access_token=$ACCESS_TOKEN" \
        | jq '.response.videos | map({url: (.files | .hls), title: .description}) | {
            list: .,
            hashkey: "url",
            title: "vkvideo",
            type: "selectable",
            fetcher: "mpv",
            pipeline: "video"}'
else
    echo "vkvideo: Unsupported url $URL" >&2
    exit 1
fi
