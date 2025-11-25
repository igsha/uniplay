#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq pandoc > /dev/null

jq -r .item \
    | read -r FILE

echo "view-html: Convert HTML [$FILE] to plain text" >&2
pandoc -f html -t plain --wrap=none --reference-links "$FILE" \
    | less
