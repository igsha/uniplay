#!/usr/bin/env bash
set -e

which grep jo > /dev/null

if ! read -r URL < <(xmllint "$1" --html -xpath '//video[@id="videoplayer"]/source//@src' 2>/dev/null \
    | grep -Po 'src="\K[^"]+' \
    | tail -n 1); then
    jo result=notmine
    exit 0
fi

echo "videoplayer: Extract $URL" >&2
if read -r SUBURL < <(grep -Po "subtitles: \K\[[^\]]+\]" "$1" | jq -r '.[0] | .src'); then
    echo "videoplayer: Extract subs $SUBURL" >&2
    jo result=video url="$URL" subsurl="$SUBURL"
else
    jo result=video url="$URL"
fi
