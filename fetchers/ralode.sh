#!/usr/bin/env bash
set -e

which grep http sed jq xmllint mpv jo > /dev/null

if ! grep -q RalodePlayer "$1"; then
    jo result=notmine
    exit 0
fi

read -r TITLE < <(grep -Po "<title>\K.+(?=</title\>)" "$1")
read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$2")
read -r URL < <(grep -Po "(?<=RalodePlayer.init\().+(?=\);)" "$1" \
    | sed '-e 1i[' -e 'a]' \
    | jq -r '.[0] | keys[0] as $k | .[$k].items | to_entries[] |
    "\(.value.aname)\t'$DOMAIN'/video.php?id=\(.value.id)"' \
    | fzf \
    | awk -F'\t' '{print $2}')

jo result=url "referer=$DOMAIN" "title=$TITLE" "url=$URL"
