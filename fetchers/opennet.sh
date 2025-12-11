#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

which jq http iconv htmlq xq sed jo > /dev/null

jq -r '.item,(.item | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

echo "opennet: Extract $URL" >&2
while [[ ! "$URL" =~ \?num=[0-9]+ ]]; do
    http GET "$URL" \
        | iconv -f koi8-r -t utf-8 \
        | mapfile HTML

    <<< "${HTML[@]}" htmlq '.ttxt2 tr:last-child a' -a href \
        | read -r NEXTURL

    <<< "${HTML[@]}" htmlq '.tdate,.title2' \
        | sed -e '1i<div>' -e '$a</div>' \
        | xq --arg dom "$DOMAIN" --arg nexturl "$DOMAIN$NEXTURL" '.div | [.td, .a] | transpose |
            {items: map({item: $dom + .[1].["@href"], name: "\(.[0].["#text"]) \(.[1].["#text"])"})
                + [{item: $nexturl, name: "###next###"}],
             title: "opennet"}' \
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
