#!/usr/bin/env bash
set -e
shopt -s lastpipe

which grep http sed jq > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.url, (.url | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
fi

echo "ralode: Extract $URL" >&2
http --follow --timeout 10 GET "$URL" $REFERER \
    | grep -Po "(?<=RalodePlayer.init\().+(?=\);)" \
    | sed -e '1i[' -e 'a]' \
    | jq --arg dom "$DOMAIN" '.[0] | to_entries | map(
        .value | .name as $name | .items | map({
            url: "\($dom)/video.php?id=\(.id)",
            title: $name + " - " + .sname
        })) | flatten | {
            list: .,
            hashkey: "url",
            referer: $dom,
            title: "ralode"}'
