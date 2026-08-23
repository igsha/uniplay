#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo xargs >/dev/null

mapfile JSON
if <<< "${JSON[@]}" jq -er '.url // empty' | read -r URL; then
    <<< "${JSON[@]}" jq -r '.headers | to_entries | map("\(.key):\(.value)") | join("\n")' \
        | mapfile HEADERS

    http GET "$URL" ${HEADERS:+"${HEADERS[@]}"} \
        | mapfile -t CONTENT

    dirname "$URL" \
        | read -r ITEMDIR

    ISURL=true
elif <<< "${JSON[@]}" jq -er '.file // empty' | read -r ITEM; then
    < "$ITEM" mapfile -t CONTENT
    ISURL=false
else
    echo "m3u8: Unsupported resource" >&2
    exit 1
fi

for LINEDATA in "${CONTENT[@]}"; do
    if [[ "$LINEDATA" =~ ^#EXTINF:[^,]+,?(.*) ]]; then
        TITLE="${BASH_REMATCH[1]}"
    elif [[ "$LINEDATA" =~ ^#EXT-X-MAP:URI=\"([^\"]+) ]]; then
        LINEDATA="${BASH_REMATCH[1]}"
        basename "$LINEDATA" \
            | read -r NAME
        if [[ "$LINEDATA" =~ ^[^/]+://[^/]+ ]]; then
            jo url="$LINEDATA" title="$NAME"
        elif [[ "$ISURL" == true ]]; then
            jo url="$ITEMDIR/$LINEDATA" title="$NAME"
        else
            jo file="$LINEDATA" title="$NAME"
        fi
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
    | jq -s --arg isurl "$ISURL" '{
            list: .,
            title: "m3u8",
            hashkey: if $isurl then "url" else "file" end,
            type: "selectable",
        }' \
    | mapfile RESULTJSON

{
    printf "%s\n" "${CONTENT[@]}" \
        | jq -sR '{content: .}'
    echo "${JSON[@]}${RESULTJSON[@]}"
} | jq -s 'add | del(.url,.file)'
