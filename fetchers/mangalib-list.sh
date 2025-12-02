#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq > /dev/null

jq -r .item \
    | read -r URL

[[ "$URL" =~ ([^/]+://[^/]+)/ru/manga/([^/]+) ]]
export DOMAIN="${BASH_REMATCH[1]}"
export REQNAME="${BASH_REMATCH[2]}"

URL="https://api.cdnlibs.org/api/manga/$REQNAME/chapters"
echo "mangalib-list: Extract $URL" >&2

http GET "$URL" \
    | jq '.data | reverse |
            {result: "urls",
             items: map("\(env.DOMAIN)/ru/\(env.REQNAME)/read/v\(.volume)/c\(.number)"),
             names: map("\(.volume)-\(.number) - \(.name)"),
             title: "mangalib"}'
