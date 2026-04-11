#!/usr/bin/env bash
# Input: any items
# Output: append random user-agent
set -e
shopt -s lastpipe

which http htmlq grep shuf sed jq > /dev/null

mapfile JSON

http GET https://seolik.ru/user-agents-list \
    | htmlq -t 'textarea#all' \
    | grep Linux \
    | shuf \
    | sed -n 1p \
    | read -r UA

echo "random-user-agent: $UA" >&2
<<< "${JSON[@]}" jq --arg ua "$UA" '.useragent = $ua'
