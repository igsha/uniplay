#!/usr/bin/env bash
set -e

which grep jo > /dev/null

if ! read -r URL < <(grep -Po '<iframe.*src="\K[^"]+' "$1" | sed 's;^//;https://;'); then
    jo result=notmine
    exit 0
fi

read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$URL")
echo "iframe: Extract $URL" >&2
jo result=url "url=$URL" "referer=$DOMAIN"
