#!/usr/bin/env bash
set -e

which grep jo > /dev/null

if ! read -r URL < <(xmllint "$1" --html -xpath '//video[@id="videoplayer"]/source//@src' 2>/dev/null \
    | grep -Po 'src="\K[^"]+' \
    | tail -n 1); then
    jo result=notmine
    exit 0
fi

jo result=video "url=$URL"
