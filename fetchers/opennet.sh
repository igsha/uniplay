#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

which jq http iconv htmlq xq sed pandoc > /dev/null

jq -r '.url,(.url | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ \?num=[0-9]+ ]]; then
    echo "opennet: Parse aricle $URL" >&2
    http GET "$URL" \
        | iconv -f koi8-r -t utf-8 \
        | htmlq '.thdr2 tr td > *, .chtext > *' -r iframe \
        | pandoc -f html -t plain --wrap=none --reference-links \
        | jq -R '{content: ., type: "text"}'

else
    echo "opennet: List news $URL" >&2
    if [[ ! "$URL" =~ /opennews ]]; then
        URL="${URL%/}/opennews/"
        echo "opennet: Extend url $URL" >&2
    fi

    http --follow GET "$URL" \
        | iconv -f koi8-r -t utf-8 \
        | mapfile HTML

    <<< "${HTML[@]}" htmlq '.ttxt2 tr:last-child a' -a href \
        | read -r NEXTURL

    <<< "${HTML[@]}" htmlq '.tdate,.title2' \
        | sed -e '1i<div>' -e '$a</div>' \
        | xq --arg dom "$DOMAIN" --arg nexturl "$DOMAIN$NEXTURL" '.div | [.td, .a] | transpose | {
            list: map({url: $dom + .[1].["@href"], title: "\(.[0].["#text"]) \(.[1].["#text"])"})
                + [{url: $nexturl, title: "###next###"}],
            hashkey: "url",
            type: "selectable",
            title: "opennet"}'
fi
