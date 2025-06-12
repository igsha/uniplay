#!/usr/bin/env bash
set -e

which grep http sed jq xmllint mpv jo > /dev/null
if ! grep -q RalodePlayer "$1"; then
    jo result=notmine
    exit 0
fi

read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$2")
IFS=$'\t' read -r ID NAME TITLE < <(grep -Po "(?<=RalodePlayer.init\().+(?=\);)" "$1" \
    | sed -e '1i[' -e 'a]' \
    | jq -r '.[0] | to_entries[] | .value.name as $name | .value.items | to_entries[] | [.value.id, $name, .value.sname] | @tsv' \
    | fzf)

jo result=url referer="$DOMAIN" title="$TITLE" url="$DOMAIN/video.php?id=$ID"
