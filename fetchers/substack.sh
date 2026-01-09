#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq tee xargs http htmlq sed xq > /dev/null

jq -r .item \
    | tee >(xargs printf "substack: Download %s\n" >&2) \
    | xargs -o http --follow GET \
    | htmlq 'title[data-rh="true"], div[data-component-name="VideoEmbedPlayer"]' \
    | sed -e '1i<div>' -e '$a</div>' \
    | tee >(xq -r '.div.div.["@id"] | "substack: Extract id [\(.)]"' >&2) \
    | xq '.div | {
        item: .div.["@id"] | ltrimstr("media-") | "https://scinquisitor.substack.com/api/v1/video/upload/\(.)/src?type=hls",
        title: .title.["#text"]}' \
    | "$UNIPLAY" -f mpv
