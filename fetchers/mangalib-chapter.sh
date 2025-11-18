#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

if [[ "$URL" =~ [^/]+://[^/]+/ru/([^/]+)/read/v([0-9]+)/c([0-9]+) ]]; then
    REQNAME="${BASH_REMATCH[1]}"
    VOLUME="${BASH_REMATCH[2]}"
    CHAPTER="${BASH_REMATCH[3]}"

    URL="https://api.cdnlibs.org/api/manga/$REQNAME/chapter?volume=$VOLUME&number=$CHAPTER"
fi

echo "mangalib-chapter: Extract $URL" >&2
http GET "$URL" \
    | jq -r '{result: "urls", items: (.data.pages | map("https://img3.mixlib.me\(.url)")), referer: "https://mangalib.me/"}'
