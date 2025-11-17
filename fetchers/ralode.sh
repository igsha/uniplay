#!/usr/bin/env bash
set -e
shopt -s lastpipe

which grep http sed jq > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
fi

http --follow --timeout 10 GET "$URL" $REFERER \
    | mapfile HTML

[[ "$URL" =~ [^/]+://[^/]+/ ]]
export DOMAIN="${BASH_REMATCH[0]}"
export BASEURL="${DOMAIN}video.php?id="

echo "Ralode: Extract $URL" >&2

<<< "${HTML[@]}" grep -Po "(?<=RalodePlayer.init\().+(?=\);)" \
    | sed -e '1i[' -e 'a]' \
    | jq '.[0] | to_entries[]
          | .value.name as $name | .value.items | to_entries
          | {result: "urls",
             items: map(env.BASEURL + .value.id),
             names: map($name + " - " + .value.sname),
             referer: env.DOMAIN}'
