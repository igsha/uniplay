#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo xargs > /dev/null

jq -r 'has("url"), .url // .file' \
    | { read -r ISURL; read -r ITEM; }

dirname "$ITEM" \
    | read -r ITEMDIR

if [[ "$ISURL" == true ]]; then
    http GET "$ITEM"
else
    cat "$ITEM"
fi \
    | while read -r LINEDATA; do
        if [[ "$LINEDATA" =~ ^#EXTINF:[^,]+,?(.*) ]]; then
            TITLE="${BASH_REMATCH[1]}"
        elif [[ ! "$LINEDATA" =~ ^# ]]; then
            TITLE="${TITLE:-$LINEDATA}"
            if [[ "$LINEDATA" =~ ^[^/]+://[^/]+ ]]; then
                jo url="$LINEDATA" -n title="$TITLE"
            elif [[ "$ISURL" == true ]]; then
                jo url="$ITEMDIR/$LINEDATA" -n title="$TITLE"
            else
                jo file="$LINEDATA" -n title="$TITLE"
            fi

            unset TITLE
        fi
    done \
    | jq -s --arg isurl "$ISURL" '{list: ., title: "m3u8", hashkey: if $isurl then "url" else "file" end, type: "selectable"}'
