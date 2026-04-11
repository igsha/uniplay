#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http >/dev/null

jq -r .url \
    | read -r URL

if [[ "$URL" =~ ([^/]+://[^/]+)/ru/manga/([^/]+) ]]; then
    DOMAIN="${BASH_REMATCH[1]}"
    REQNAME="${BASH_REMATCH[2]}"
    echo "mangalib: List chapters $URL" >&2

    URL="https://api.cdnlibs.org/api/manga/$REQNAME/chapters"
    echo "mangalib: Extract $URL" >&2

    http GET "$URL" "referer:$DOMAIN" \
        | jq --arg dom "$DOMAIN" --arg req "$REQNAME" '.data | reverse | {
            list: map({
                url: "\($dom)/ru/\($req)/read/v\(.volume)/c\(.number)",
                title: "\(.volume)-\(.number) - \(.name)"
            }),
            hashkey: "url",
            type: "selectable",
            title: "mangalib"}'
else
    if [[ "$URL" =~ [^/]+://[^/]+/ru/([^/]+)/read/v([0-9]+)/c([0-9]+) ]]; then
        REQNAME="${BASH_REMATCH[1]}"
        VOLUME="${BASH_REMATCH[2]}"
        CHAPTER="${BASH_REMATCH[3]}"

        URL="https://api.cdnlibs.org/api/manga/$REQNAME/chapter?volume=$VOLUME&number=$CHAPTER"
    elif [[ ! "$URL" =~ api.cdnlibs.org/api/manga ]]; then
        echo "mangalib: Wrong url $URL" >&2
        exit 1
    fi

    echo "mangalib-chapter: Extract chapter $URL" >&2
    http GET "$URL" "referer:https://mangalib.me/" \
        | jq -r '{
            list: (.data.pages | map({url: "https://img3.mixlib.me\(.url)"})),
            referer: "https://mangalib.me/",
            type: "images",
            parallel: 4,
            pipeline: "manga"}'
fi
