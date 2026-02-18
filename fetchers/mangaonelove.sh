#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http jo sed htmlq grep xq xargs tee > /dev/null

jq -r .item \
    | xargs -I{} -o http --follow GET "{}" \
    | htmlq 'ul.main.version-chap' --remove-nodes .c-new-tag \
    | xq '[.. | objects | select(has("@class") and (.["@class"] | startswith("wp-manga-chapter"))) | .a] |
          {items: map({item: .["@href"], name: .["#text"]}),
           title: "mangaonelove"}' \
    | "$UNIPLAY" -f marksel \
    | jq -r .item \
    | tee >(awk '{printf "mangaonelove: Extract chapter %s\n", $0}' >&2) \
    | xargs -I{} -o http GET "{}" \
    | htmlq '#chapter_preloaded_images' -t \
    | grep -Po '\[.+\]' \
    | jo result=urls items=:- parallel=4 \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
