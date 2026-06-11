#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http pandoc htmlq >/dev/null

jq -r .url \
    | read -r URL

http GET "$URL" \
    | mapfile HTML

if [[ "$URL" =~ /news/[0-9]+/[0-9]+/[0-9]+/.+ ]]; then
    echo "nplus1: Download article $URL" >&2
    <<< "${HTML[@]}" htmlq '#appfront section > div .flex-wrap > div:nth-child(1) .duration-75, #appfront section > div .flex.flex-col' \
        | pandoc -f html -t plain --wrap=none --reference-links \
        | jq -R '{content: ., type: "text"}'
else
    echo "nplus1: Extract JSON $URL" >&2
    <<< "${HTML[@]}" grep -Po "JSON.parse\('\K[^']+" \
        | read -r JSON

    echo "nplus1: List articles" >&2
    JSON="${JSON//\\\//\/}"
    printf "$JSON" \
        | sed $'s;\\/;/;g' \
        | jq '.next_page_url as $next | .data | {
            list: map({url, title}) + [select($next != null) | {url: $next, title: "###next###"}],
            title: "nplus1",
            type: "selectable",
            hashkey: "url"}'
fi
