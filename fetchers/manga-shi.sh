#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo > /dev/null

mapfile -t JSON
printf "%s\n" "${JSON[@]}" \
    | jq -r '.item, (.item | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ [^/]+://[^/]+/manga/[^/]+/?$ ]]; then
    TBLNAME="${URL%/}"
    TBLNAME="${TBLNAME##*/}"

    URL="${URL%/}/chapters/?chapter_sort=latest"
    while [[ "$URL" =~ /chapters/ ]]; do
        echo "manga-shi: List chapters $URL" >&2
        http --follow GET "$URL" \
            | htmlq  \
            | xq --arg base "$DOMAIN" '.html.body
                | if (.div != null) then .a += [{"@href": .div.["@hx-get"], span: [{span: "###next###"}]}] end | {
                    items: .a | map({item: $base + .["@href"], name: .span[0].span}),
                    title: "manga-shi"
                }' \
            | "$UNIPLAY" -f marksel \
            | jq -r '.item, .title' \
            | { read -r URL; read -r TITLE; }
    done
fi

echo "manga-shi: Download chapter $URL [$TITLE]" >&2
http --follow GET "$URL" \
    | htmlq '.reader-pages .reader-page img' \
    | sed -e 's;\(<img.*\)>;\1/>;g' -e '1i<div>' -e '$a</div>' \
    | xq --arg base "$DOMAIN" --arg title "$TITLE" \
        '.div.img | {items: map(.["@data-src"] // .["@src"] | $base + .), title: $title, parallel: 4}' \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
