#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo http htmlq xq fzf > /dev/null

jq -r .item \
    | read -r URL

DOMAIN="${URL%${URL#*//*/}}"

http --follow --timeout 5 GET "$URL" \
    | mapfile HTML

export DOMAIN TITLE
<<< "${HTML[@]}" htmlq .serial-translations-box \
    | xq -r '.div.select.option[] | [
        "\(env.DOMAIN)\(.["@data-media-type"])/\(.["@data-media-id"])/\(.["@data-media-hash"])/720p",
        .["#text"]] | @tsv' \
    | fzf -d $'\t' --with-nth=2 --accept-nth=1 \
    | jo result=url item=@-
