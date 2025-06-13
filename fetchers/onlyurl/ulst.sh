#!/usr/bin/env bash
set -e

which jo > /dev/null
if [[ ! "$1" =~ \.(ulst|m3u8)$ ]]; then
    jo result=notmine
    exit 0
fi

read -r URL < <(grep -v "^#" "$1" | fzf)
jo result=url url="$URL"
