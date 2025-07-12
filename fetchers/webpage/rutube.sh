#!/usr/bin/env bash
set -e

which grep jo > /dev/null
if [[ ! "$2" =~ https?://rutube.ru/u/([0-9A-Za-z]+)/?([^/]+)? ]]; then
    jo result=notmine
    exit 0
fi

read -r USERID < <(grep -Po '"userChannelId":\K\d+' "$1" | head -1)
jo result=url "url=https://rutube.ru/channel/$USERID/${BASH_REMATCH[2]}"
