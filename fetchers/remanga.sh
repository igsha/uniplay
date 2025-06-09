#!/usr/bin/env bash
set -e

which grep http jq fzf parallel magick jo pdfcpu > /dev/null

if [[ ! "$2" =~ remanga ]]; then
    jo result=notmine
    exit 0
fi

URL="$2" # E.g.,https://remanga.org/manga/one-punch-man-one
URL="${URL%%\?*}" # Remove query part
DIR="$XDG_CACHE_HOME/uniplayer/remanga"

mark() {
    while IF=$'\t' read -r CHAPTER ID; do
        MARK="(new)"
        if [[ -d "$1/$ID" ]]; then
            MARK="(cached)"
        fi

        printf "%s\t$CHAPTER\t$ID\n" "$MARK"
    done
}

read -r DOMAIN < <(grep -Po '.+//[^/]+' <<< "$URL")
read -r REQNAME < <(grep -Po '.+//[^/]+/[^/]+/\K[^/]+' <<< "$URL")
IFS=$'\t' read -r NAME BRANCHID < <(http GET "https://api.remanga.org/api/v2/titles/$REQNAME/" \
    | jq -r '"\(.secondary_name | sub("/"; "-"))\t\(.branches[0].id)"')

IFS=$'\t' read -r MARKED CHAPTER ID < <(http GET "https://api.remanga.org/api/v2/titles/chapters/?branch_id=$BRANCHID&ordering=index" \
    | jq -r '.results[] | "\(.chapter)\t\(.id)"' \
    | mark "$DIR/$NAME" \
    | fzf)

DIR="$DIR/$NAME/$ID"
mkdir -p "$DIR"

PDFFILE="$DIR/$NAME - $CHAPTER.pdf"
if [[ "$MARKED" != "(cached)" ]]; then
    FILES=()
    URLS=()
    while IFS=$'\t' read -r URL FILE; do
        FILES+=("$FILE")
        URLS+=("$URL")
    done < <(http GET "https://api.remanga.org/api/v2/titles/chapters/$ID/" \
        | jq -r '.pages | flatten | .[] | "\(.link)\t'"$DIR/"'\(.link | split("/")[-1])"')

    echo Extract pages... >&2
    parallel --colsep='\t' -kq http GET {1} "referer:$DOMAIN" -o {2} ::: "${URLS[@]}" :::+ "${FILES[@]}"
    echo Convert pages... >&2
    magick \( "${FILES[@]}" -append \) -crop 1x${#FILES[@]}@ +repage "$DIR"/replaced_%04d.jpg >&2
    echo Create pdf... >&2
    pdfcpu import -c disable "$PDFFILE" "$DIR"/replaced_*.jpg >&2
    echo Remove pages... >&2
    rm "${FILES[@]}"
    rm "$DIR"/replaced_*.jpg
fi

jo result=pdf url="$PDFFILE"
