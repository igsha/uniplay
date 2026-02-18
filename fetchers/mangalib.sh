#!/usr/bin/env bash
set -e
shopt -s lastpipe

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

echo "mangalib: Extract $URL" >&2

<<< "${JSON[@]}" "$UNIPLAY" -f mangalib-list \
    | "$UNIPLAY" -f marksel \
    | "$UNIPLAY" -f mangalib-chapter \
    | jq '.parallel=4' \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
