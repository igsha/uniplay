#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq >/dev/null

mapfile JSON
<<< "${JSON[@]}" "$UNIPLAY" m3u8 \
    | jq '.parallel=4' \
    | "$UNIPLAY" download \
    | mapfile JSONFILES

<<< "${JSONFILES[@]}" jq -r '.delete' \
    | read -r DELETEDIR

[[ -d "$DELETEDIR" ]]

M3U8FILE="$DELETEDIR/master.m3u8"
echo "download-m3u8: Save m3u8 to $M3U8FILE" >&2
<<< "${JSONFILES[@]}" jq -r .content > "$M3U8FILE"

<<< "${JSON[@]}" jq --arg dd "$DELETEDIR" --arg file "$M3U8FILE" 'del(.url,.headers) |
    [., {file: $file, type: "video", delete: $dd}] | add'
