#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http iconv htmlq tee awk jo > /dev/null

jq -r '.item | split("/")[3] | sub("^video"; "")' \
    | read -r VIDEOID

URL="https://vk.com/al_video.php"
echo "vkvideo: Get info $VIDEOID from $URL" >&2
http --ignore-stdin -f POST "$URL" act=show "video=$VIDEOID" al=1 "Referer:$URL" X-Requested-With:XMLHttpRequest \
    | iconv -f cp1251 \
    | jq -r '.payload[1] | .[0], .[1]' \
    | { read -r TITLE; mapfile HTML; }

echo "vkvideo: Take the second video" >&2
<<< "${HTML[@]}" htmlq source -a src \
    | tee >(awk '{print "vkvideo:", $0}' >&2) \
    | jo -a \
    | jq --arg title "$TITLE" '{item: .[1], title: $title}' \
    | "$UNIPLAY" -f mpv
