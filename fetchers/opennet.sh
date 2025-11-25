#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http iconv htmlq sed jo paste > /dev/null

jq -r '.item,(.item | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

echo "opennet: Extract $URL" >&2
while [[ ! "$URL" =~ \?num=[0-9]+ ]]; do
    http GET "$URL" \
        | iconv -f koi8-r -t utf-8 \
        | mapfile HTML

    <<< "${HTML[@]}" htmlq '.ttxt2 tr:last-child a' -a href \
        | sed "s;^;${DOMAIN}/;" \
        | read -r NEXTURL

    <<< "${HTML[@]}" htmlq .title2 -a href \
        | sed "s;^;${DOMAIN}/;" \
        | sed "\$a$NEXTURL" \
        | jo -a \
        | read -r URLS

    <<< "${HTML[@]}" htmlq '.tdate,.title2' -t \
        | paste -d ' ' - - \
        | sed '$a###next###' \
        | jo -a \
        | read -r NAMES

    jo result=urls items="$URLS" names="$NAMES" title="opennet" \
        | "$UNIPLAY" -f marksel \
        | jq -r .item \
        | read -r URL
done

mktemp -t uniplay.opennet.XXX.html \
    | read -r FILE

echo "opennet: Parse $URL -> $FILE" >&2
http GET "$URL" \
    | iconv -f koi8-r -t utf-8 \
    | htmlq '.thdr2 tr td > *, .chtext > *' -r iframe > "$FILE"

jo result=file item="$FILE" delete="$FILE" \
    | "$UNIPLAY" -f view-html
