#!/usr/bin/env bash
set -e
shopt -s lastpipe

which grep http sed jq > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.item, (.item | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
fi

echo "ralode: Extract $URL" >&2
http --follow --timeout 10 GET "$URL" $REFERER \
    | mapfile HTML

echo "Ralode: Parse html" >&2
<<< "${HTML[@]}" grep -Po "(?<=RalodePlayer.init\().+(?=\);)" \
    | sed -e '1i[' -e 'a]' \
    | jq --arg dom "$DOMAIN" '.[0] | to_entries[]
          | .value.name as $name | .value.items | to_entries
          | {result: "urls",
             items: map({item: "\($dom)/video.php?id=\(.value.id)", name: $name + " - " + .value.sname}),
             title: "ralode",
             referer: $dom}'
