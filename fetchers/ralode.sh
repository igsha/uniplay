#!/usr/bin/env bash
set -e

which grep http sed jq fzf > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .item <<< "${JSON[@]}")
if read -r REFERER < <(jq -r '.referer // empty' <<< "${JSON[@]}"); then
    REFERER="referer:$REFERER"
fi

read -r REGISTER < <(mktemp -t uniplayer.ralode.XXX)
trap "rm \"$REGISTER\"" INT EXIT
http --follow --timeout 10 GET "$URL" $REFERER > "$REGISTER"

read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$URL")
IFS=$'\t' read -r ID NAME TITLE < <(grep -Po "(?<=RalodePlayer.init\().+(?=\);)" "$REGISTER" \
    | sed -e '1i[' -e 'a]' \
    | jq -r '.[0] | to_entries[] | .value.name as $name | .value.items | to_entries[] | [.value.id, $name, .value.sname] | @tsv' \
    | fzf)

export URL="$DOMAIN/video.php?id=$ID" DOMAIN TITLE
echo "Ralode: Extract $URL" >&2
jq '.title=env.TITLE | .referer=env.DOMAIN | .item=env.URL' <<< "${JSON[@]}"
