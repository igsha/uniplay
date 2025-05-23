#!/usr/bin/env bash
set -e

URL="$1" # E.g.,https://remanga.org/manga/one-punch-man-one
URL="${URL%%\?*}" # Remove query part

read -r DOMAIN < <(grep -Po '.+//[^/]+' <<< "$URL")
read -r REQNAME < <(grep -Po '.+//[^/]+/[^/]+/\K[^/]+' <<< "$URL")
mapfile -t < <(http GET "https://api.remanga.org/api/v2/titles/$REQNAME/" \
    | jq -r '(.secondary_name | sub("/"; "-")),.branches[0].id')

read -r ID < <(http GET "https://api.remanga.org/api/v2/titles/chapters/?branch_id=${MAPFILE[1]}&ordering=index" \
    | jq -r '.results[] | "\(.chapter)\t\(.id)"' \
    | fzf --with-nth=1 \
    | awk -F'\t' '{print $2}')

read -r DIR < <(mktemp -d)
echo "Tempdir $DIR"

http GET "https://api.remanga.org/api/v2/titles/chapters/$ID/" \
    | jq -r '.pages | flatten | .[] | .link' \
    | parallel -k http GET "{1}" "referer:$DOMAIN" -o "$DIR/{1/}" '&&' echo "$DIR/{1/}" \
    | xargs pdfcpu import "$DIR/$NAME.pdf"

xdg-open "$DIR/$NAME.pdf"
rm -r "$DIR"
