#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo > /dev/null

mapfile -t JSON
printf "%s\n" "${JSON[@]}" \
    | jq -r .url \
    | read -r URL

if [[ "$URL" =~ [^/]+://[^/]+/manga/[^/]+/?$ ]]; then
    TBLNAME="${URL%/}"
    TBLNAME="${TBLNAME##*/}"
    echo "manga-shi: Choose chapter for [$TBLNAME]" >&2

    <<< "${JSON[@]}" "$UNIPLAY" -f manga-shi-list \
        | "$UNIPLAY" -f marksel \
        | jq -r '.url' \
        | read -r URL
fi

echo "manga-shi: Download chapter $URL" >&2
jo result=url url="$URL" \
    | "$UNIPLAY" -f manga-shi-chapter \
    | "$UNIPLAY" -f download \
    | "$UNIPLAY" -f create-pdf \
    | "$UNIPLAY" -f pdf
