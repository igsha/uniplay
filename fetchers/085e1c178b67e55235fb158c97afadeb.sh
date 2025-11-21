#!/usr/bin/env bash
set -e
shopt -s lastpipe

mapfile JSON
<<< "${JSON[@]}" jq -r '.item,(.item | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

echo "085e1c178b67e55235fb158c97afadeb: Extract $URL" >&2
http GET "$URL" \
    | htmlq '.post_content.cf img' -a data-src \
    | sed -e "s;^;${DOMAIN};g" -e '/.*\.gif$/d' \
    | jo -a \
    | jo items=:- referer="$DOMAIN" \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
