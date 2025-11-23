#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http jo sed htmlq grep > /dev/null

jq -r .item \
    | read -r URL

http GET "$URL" \
    | mapfile HTML

<<< "${HTML[@]}" htmlq '.wp-manga-chapter a' -a href \
    | jo -a \
    | read -r URLS

<<< "${HTML[@]}" htmlq '.wp-manga-chapter a' -t \
    | sed '/^$/d;s/^[[:blank:]]*//;s/[[:blank:]]*$//' \
    | jo -a \
    | read -r NAMES

<<< "${HTML[@]}" htmlq title -t \
    | read -r TITLE

jo result=urls items="$URLS" names="$NAMES" title="$TITLE" \
    | "$UNIPLAY" -f marksel \
    | jq -r .item \
    | read -r URL

http GET "$URL" \
    | htmlq '#chapter_preloaded_images' -t \
    | grep -Po '\[.+\]' \
    | jo result=urls items=:- \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
