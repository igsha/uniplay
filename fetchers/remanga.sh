#!/usr/bin/env bash
set -e

which grep http jq fzf parallel magick pdfcpu > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")

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

read -r DOMAIN < <(grep -Po '.+//[^/]+/' <<< "$URL")
read -r REQNAME < <(grep -Po '.+//[^/]+/[^/]+/\K[^/]+' <<< "$URL")
echo "Remanga: Download list https://api.remanga.org/api/v2/titles/$REQNAME/" >&2
IFS=$'\t' read -r NAME BRANCHID < <(http GET "https://api.remanga.org/api/v2/titles/$REQNAME/" \
    | jq -r '"\(.secondary_name | sub("/"; "-"))\t\(.branches[0].id)"')

BASEURL="https://api.remanga.org/api/v2/titles/chapters/?branch_id=$BRANCHID&ordering=index"
CHAPTER="1"
ID=next
ORIGIN=0
while [[ "$ID" == next ]]; do
    URL="$BASEURL&page=$CHAPTER"
    echo "Remanga: Download chapters $URL" >&2
    mapfile -O "$ORIGIN" -t LINES < <(http GET "$URL" \
        | jq -r '(.results + [.next | select(. != null) | {chapter: ., id: "next"}]) | .[] | [.chapter, .id] | @tsv')
    ORIGIN=$((${#LINES[@]}-1))
    IFS=$'\t' read -r CHAPTER ID <<< "${LINES[$ORIGIN]}"
done

IFS=$'\t' read -r MARKED CHAPTER ID < <(printf "%s\n" "${LINES[@]}" \
    | mark "$DIR/$NAME" \
    | fzf)

DIR="$DIR/$NAME/$ID"
mkdir -p "$DIR"

PDFFILE="$DIR/$NAME - $CHAPTER.pdf"
if [[ "$MARKED" != "(cached)" ]]; then
    read -r IMGTMPDIR < <(mktemp -d)
    FILES=()
    URLS=()
    echo "Remanga: Download chapter https://api.remanga.org/api/v2/titles/chapters/$ID/" >&2
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

export PDFFILE
<<< "${JSON[@]}" jq '.result="pdf" | .url=env.PDFFILE' | "$UNI" pdf
