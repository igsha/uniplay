#!/usr/bin/env bash
set -e
shopt -s lastpipe

jq -r .item \
    | read -r URL

if [[ ! "$URL" =~ /rss/.+\.xml$ ]]; then
    echo "cnews: Extract rss from $URL" >&2
    http --follow GET "$URL" \
        | htmlq '.fc-links' --remove-nodes img \
        | xq -r '.ul.li[].a | select(.["#text"] == "RSS") | .["@href"]' \
        | read -r URL
fi

if [[ ! "$URL" =~ /news/line/ ]]; then
    echo "cnews: Extract news $URL" >&2
    http GET "$URL" \
        | xq '.rss.channel.item | {items: map({item: .link, name: .title}), title: "cnews"}' \
        | "$UNIPLAY" -f marksel \
        | jq -r .item \
        | read -r URL
fi

mktemp -t uniplay.cnews.XXX.html \
    | read -r FILE

echo "cnews: Parse $URL -> $FILE" >&2
http GET "$URL" \
    | htmlq '.article-date-desktop, article' \
    | htmlq --remove-nodes 'aside, nofollow, noindex, .comments_all, article > div' > "$FILE"

jo result=file item="$FILE" delete="$FILE" \
    | "$UNIPLAY" -f view-html
