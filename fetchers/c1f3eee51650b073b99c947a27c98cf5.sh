#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq tr xq >/dev/null

jq -r '.url, (.url | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ /vol[0-9]+/[0-9]+ ]]; then
    echo "c1f3eee51650b073b99c947a27c98cf5: Extract chapter $URL" >&2
    http GET "$URL" referer:"$DOMAIN" \
        | mapfile HTML

    <<< "${HTML[@]}" htmlq title -t \
        | read -r TITLE

    <<< "${HTML[@]}" grep -oP "readerInit.*\K\[\[.+\]\]" \
        | tr "'" '"' \
        | jq --arg title "$TITLE" --arg dom "$DOMAIN" '{
            list: (to_entries | map(.value.[0] + (.value.[2] | split("?")[0]) as $url | {
                url: "https:" + ($url | sub("//bru\\."; "//cru.")),
                title: (.key as $index | $url | split("/").[-1] | "\($index).\(.)")})),
            type: "images",
            referer: $dom,
            pipeline: "manga",
            title: $title}'
else
    echo "c1f3eee51650b073b99c947a27c98cf5: List chapters $URL" >&2
    http GET "$URL" referer:"$DOMAIN" \
        | htmlq '#chapters-list .chapter-link' \
        | htmlq \
        | xq --arg url "$DOMAIN" '.html.body.a | {
            list: if type == "array" then . else [.] end | map({
                url: $url + .["@href"],
                title: .["#text"]
            }),
            hashkey: "url",
            title: "c1f3eee51650b073b99c947a27c98cf5",
            type: "selectable"}'
fi
