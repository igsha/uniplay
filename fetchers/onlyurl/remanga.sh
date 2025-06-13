#!/usr/bin/env bash
set -e

which grep http jq fzf parallel magick jo pdfcpu > /dev/null
if [[ ! "$1" =~ remanga ]]; then
    jo result=notmine
    exit 0
fi

URL="$1" # E.g.,https://remanga.org/manga/one-punch-man-one
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
echo "Remanga: Download list https://api.remanga.org/api/v2/titles/$REQNAME/" >&2
IFS=$'\t' read -r NAME BRANCHID < <(http GET "https://api.remanga.org/api/v2/titles/$REQNAME/" \
    | jq -r '"\(.secondary_name | sub("/"; "-"))\t\(.branches[0].id)"')

echo "Remanga: Download chapters https://api.remanga.org/api/v2/titles/chapters/?branch_id=$BRANCHID&ordering=index" >&2
APIURL="https://api.remanga.org"
ID=next
CHAPTER="/api/v2/titles/chapters/?branch_id=$BRANCHID&ordering=index"
while [[ "$ID" == next ]]; do
    URL="$APIURL$CHAPTER"
    IFS=$'\t' read -r MARKED CHAPTER ID < <(http GET "$URL" \
        | jq -r '(.results + [.next | select(. != null) | {chapter: ., id: "next"}]) | .[] | [.chapter, .id] | @tsv' \
        | mark "$DIR/$NAME" \
        | fzf)
done

DIR="$DIR/$NAME/$ID"
mkdir -p "$DIR"

PDFFILE="$DIR/$NAME - $CHAPTER.pdf"
if [[ "$MARKED" != "(cached)" ]]; then
    read -r IMGTMPDIR < <(mktemp -d)
    FILES=()
    URLS=()
    while IFS=$'\t' read -r URL FILE; do
        FILES+=("$FILE")
        URLS+=("$URL")
    done < <(http GET "https://api.remanga.org/api/v2/titles/chapters/$ID/" \
        | jq -r '.pages | flatten | .[] | "\(.link)\t'"$IMGTMPDIR/"'\(.link | split("/")[-1])"')

    echo Remanga: Extract pages... >&2
    parallel --colsep='\t' -kq http GET {1} "referer:$DOMAIN" -o {2} ::: "${URLS[@]}" :::+ "${FILES[@]}"
    echo Remanga: Convert pages... >&2
    magick \( "${FILES[@]}" -append \) -crop 1x${#FILES[@]}@ +repage "$IMGTMPDIR"/replaced_%04d.jpg >&2
    echo Remanga: Create pdf... >&2
    pdfcpu import -c disable "$PDFFILE" "$IMGTMPDIR"/replaced_*.jpg >&2
    echo Remanga: Remove pages... >&2
    rm -r "$IMGTMPDIR"
fi

jo result=pdf url="$PDFFILE"
