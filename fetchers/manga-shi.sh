#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq sed htmlq > /dev/null

mapfile -t JSON
printf "%s\n" "${JSON[@]}" \
    | jq -r .url \
    | read -r URL

TBLNAME="${URL%/}"
TBLNAME="${TBLNAME##*/}"

echo "manga-shi: Download chapters ${URL%/}/ajax/chapters" >&2
http POST "${URL%/}/ajax/chapters" \
    | mapfile -t HTML

<<< "${HTML[@]}" htmlq 'li a' -t \
    | sed '/^$/d;s/^[[:blank:]]*//;s/[[:blank:]]*$//' \
    | jo -a \
    | read -r NAMES

<<< "${HTML[@]}" htmlq 'li a' -a href \
    | jo -a \
    | read -r URLS

jo result=urls urls="$URLS" names="$NAMES" title="$TBLNAME" \
    | "$UNIPLAY" -f marksel \
    | jq -r '.url' \
    | read -r URL

echo "manga-shi: Download chapter $URL" >&2
http --follow GET "$URL" \
    | htmlq '.reading-content div > img' -a data-src \
    | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' \
    | jo -a \
    | jq '{urls: ., result: "urls"}' \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
