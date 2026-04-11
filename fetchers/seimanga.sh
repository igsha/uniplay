#!/usr/bin/env bash
set -e
shopt -s lastpipe

jq -r '.url, (.url | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

http GET "$URL" \
    | mapfile HTML

if [[ "$URL" =~ /vol[0-9]+/ ]]; then
    echo "seimanga: Extract images $URL" >&2
    <<< "${HTML[@]}" htmlq .mobile-title-container \
        | xq -r '.div | .strong.["#text"][0:100] + "... " + .span.["#text"]' \
        | read -r TITLE

    <<< "${HTML[@]}" grep -oP "readerInit.*\K\[\[.+\]\]" \
        | tr "'" '"' \
        | jq --arg title "$TITLE" '{
            list: (to_entries | map(.value.[0] + (.value.[2] | split("?")[0]) as $url | {
                url: $url,
                title: (.key as $index | $url | split("/").[-1] | "\($index).\(.)")})),
            type: "images",
            pipeline: "manga",
            title: $title}'
else
    echo "seimanga: List chapters $URL" >&2
    <<< "${HTML[@]}" htmlq 'table a' \
        | sed -e '1i<div>' -e '$a</div>' \
        | xq --arg dom "$DOMAIN" '.div.a | {
            list: map({url: $dom + .["@href"] + "?mtr=true", title: .["#text"]}),
            hashkey: "url",
            type: "selectable",
            title: "seimanga"}'
fi
