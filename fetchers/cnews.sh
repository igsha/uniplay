#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq xq pandoc jo >/dev/null

jq -r .url \
    | read -r URL

if [[ "$URL" =~ /news/(line|top)/ ]]; then
    echo "cnews: Parse $URL" >&2
    http GET "$URL" \
        | htmlq '.article-date-desktop, article' \
        | htmlq --remove-nodes 'aside, nofollow, noindex, .comments_all, article > div' \
        | pandoc -f html -t plain --wrap=none --reference-links \
        | jo content=@- type=text
else
    if [[ ! "$URL" =~ /rss/.+\.xml$ ]]; then
        echo "cnews: Extract rss from $URL" >&2
        http --follow GET "$URL" \
            | htmlq '.fc-links' --remove-nodes img \
            | xq -r '.ul.li[].a | select(.["#text"] == "RSS") | .["@href"]' \
            | read -r URL
    fi

    echo "cnews: List news $URL" >&2
    http GET "$URL" \
        | xq '.rss.channel.item | {list: map({url: .link, title}), title: "cnews", hashkey: "url", type: "selectable"}'
fi
