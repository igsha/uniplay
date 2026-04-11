#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo > /dev/null

jq -r '.url, (.url | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ [^/]+://[^/]+/manga/[^/]+/?$ ]]; then
    URL="${URL%/}/chapters/?chapter_sort=latest"
fi

if [[ "$URL" =~ /chapters/ ]]; then
    echo "manga-shi: List chapters $URL" >&2
    http --follow GET "$URL" \
        | htmlq \
        | xq --arg base "$DOMAIN" '.html.body
            | if (.div != null) then .a += [{"@href": .div.["@hx-get"], span: [{span: "###next###"}]}] end | {
                list: .a | map({url: $base + .["@href"], title: .span[0].span}),
                hashkey: "url",
                type: "selectable",
                title: "manga-shi"
            }'
elif [[ "$URL" =~ /manga/[^/]+/glava- ]]; then
    echo "manga-shi: Download chapter $URL" >&2

    http --follow GET "$URL" \
        | htmlq '.reader-pages .reader-page img' \
        | sed -e 's;\(<img.*\)>;\1/>;g' -e '1i<div>' -e '$a</div>' \
        | xq --arg base "$DOMAIN" '.div.img | {
            list: map({url: (.["@data-src"] // .["@src"] | $base + .), title}),
            parallel: 4,
            type: "images",
            pipeline: "manga"}'
else
    echo "manga-shi: Wrong url $URL" >&2
    exit 1
fi
