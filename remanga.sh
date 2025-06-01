#!/usr/bin/env bash
set -e

which grep http jq fzf parallel pdfcpu xdg-open magick > /dev/null

URL="$1" # E.g.,https://remanga.org/manga/one-punch-man-one
URL="${URL%%\?*}" # Remove query part
DIR="$XDG_CACHE_HOME/remanga"

mark() {
    while IF=$'\t' read -r CHAPTER ID; do
        printf "$CHAPTER\t$ID"
        if [[ -d "$1/$ID" ]]; then
            printf "\t*"
        fi

        printf "\n"
    done
}

read -r DOMAIN < <(grep -Po '.+//[^/]+' <<< "$URL")
read -r REQNAME < <(grep -Po '.+//[^/]+/[^/]+/\K[^/]+' <<< "$URL")
IFS=$'\t' read -r NAME BRANCHID < <(http GET "https://api.remanga.org/api/v2/titles/$REQNAME/" \
    | jq -r '"\(.secondary_name | sub("/"; "-"))\t\(.branches[0].id)"')

IFS=$'\t' read -r CHAPTER ID MARKED < <(http GET "https://api.remanga.org/api/v2/titles/chapters/?branch_id=$BRANCHID&ordering=index" \
    | jq -r '.results[] | "\(.chapter)\t\(.id)"' \
    | mark "$DIR/$NAME" \
    | fzf)

DIR="$DIR/$NAME/$ID"
mkdir -p "$DIR"

PDFFILE="$DIR/$NAME - $CHAPTER.pdf"
if [[ -z "$MARKED" ]]; then
    mapfile -t < <(http GET "https://api.remanga.org/api/v2/titles/chapters/$ID/" \
        | jq -r '.pages | flatten | .[] | .link' \
        | parallel -k http GET {1} "referer:$DOMAIN" -o \"$DIR/{1/}\" '&&' echo \"$DIR/{1/}\")
    magick \( "${MAPFILE[@]}" -append \) -crop 1x${#MAPFILE[@]}@ +repage "$DIR"/replaced_%04d.jpg
    pdfcpu import -c disable "$PDFFILE" "$DIR"/replaced_*.jpg
fi

xdg-open "$PDFFILE"
