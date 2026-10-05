#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo xargs >/dev/null

mapfile JSON
if <<< "${JSON[@]}" jq -er '.url // empty' | read -r URL; then
    <<< "${JSON[@]}" "$UNIPLAY" http \
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

printf "%s\n" "${CONTENT[@]}" \
    | awk '/#EXT-X-STREAM-INF/{getline; print}' \
    | mapfile -t INDEXURL

if [[ "${#INDEXURL[@]}" -eq 0 ]]; then
    echo "m3u8: Process m3u8 index" >&2
    NEWCONTENT=()
    JSONARR=()
    for LINEDATA in "${CONTENT[@]}"; do
        if [[ "$LINEDATA" =~ ^#EXTINF:[^,]+,?(.*) ]]; then
            TITLE="${BASH_REMATCH[1]}"
            NEWCONTENT+=("$LINEDATA")
        elif [[ "$LINEDATA" =~ ^(#EXT-X-MAP:URI=\")([^\"]+)(.*) ]]; then
            FIRSTPART="${BASH_REMATCH[1]}"
            LINEDATA="${BASH_REMATCH[2]}"
            LASTPART="${BASH_REMATCH[3]}"
            basename "$LINEDATA" \
                | read -r NAME

            if [[ "$LINEDATA" =~ ^[^/]+://[^/]+ ]]; then
                jo url="$LINEDATA" title="$NAME"
            elif [[ "$ISURL" == true ]]; then
                jo url="$ITEMDIR/$LINEDATA" title="$NAME"
            else
                jo file="$LINEDATA" title="$NAME"
            fi \
                | mapfile -O "${#JSONARR[@]}" JSONARR

            NEWCONTENT+=("$FIRSTPART$NAME$LASTPART")
        elif [[ ! "$LINEDATA" =~ ^# ]]; then
            TITLE="${TITLE:-$LINEDATA}"
            if [[ "$LINEDATA" =~ ^[^/]+://[^/]+ ]]; then
                jo url="$LINEDATA" -n title="$TITLE"
            elif [[ "$ISURL" == true ]]; then
                jo url="$ITEMDIR/$LINEDATA" -n title="$TITLE"
            else
                jo file="$LINEDATA" -n title="$TITLE"
            fi \
                | mapfile -O "${#JSONARR[@]}" JSONARR

            NEWCONTENT+=("$TITLE")
            unset TITLE
        else
            NEWCONTENT+=("$LINEDATA")
        fi
    done

    {
        printf "%s\n" "${NEWCONTENT[@]}" \
            | jq -sR '{content: .}'
        echo "${JSON[@]}"
        <<< "${JSONARR[@]}" jq -s --arg isurl "$ISURL" '{
                list: .,
                title: "m3u8",
                hashkey: if $isurl then "url" else "file" end,
                type: "selectable",
            }'
    } | jq -s 'add | del(.url,.file)'
elif [[ "${#INDEXURL[@]}" -eq 1 ]]; then
    echo "m3u8: Read index ${INDEXURL[0]}" >&2
    <<< "${JSON[@]}" jq --arg url "$ITEMDIR/${INDEXURL[0]}" '.url=$url' \
        | "$UNIPLAY" m3u8
else
    printf "m3u8: Unsupported several indexes %s\n" "${INDEXURL[@]}" >&2
    exit 1
fi
