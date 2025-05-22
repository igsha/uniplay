#!/usr/bin/env bash
set -e

which grep http sed jq xmllint mpv > /dev/null

read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$1")
read -r TITLE < <(http GET "$1" | grep -Po "<title>\K.+(?=</title\>)")
read -r URL < <(http GET "$1" \
    | grep -Po "(?<=RalodePlayer.init\().+(?=\);)" \
    | sed '-e 1i[' -e 'a]' \
    | jq -r '.[0] | keys[0] as $k | .[$k].items | to_entries[] |
    "\(.value.aname)\t'$DOMAIN'/video.php?id=\(.value.id)"' \
    | fzf \
    | awk -F'\t' '{print $2}')

read -r URL < <(http GET "$URL" "referer:$DOMAIN" \
    | grep -Po '<iframe.*src="\K[^"]+' \
    | sed 's;^//;https://;')
echo "Extracted URL: $URL"

read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$URL") # Update referer
read -r URL < <(http GET "$URL" "referer:$DOMAIN" \
    | grep -Pzo '(?s)<video.*?</video>' \
    | xmllint - --html --xpath 'string(//video/source[@res="720"]/@src)' 2>/dev/null)

echo "Play URL: $URL"
mpv --http-header-fields="Referer: $DOMAIN" --title="$TITLE" "$URL"
