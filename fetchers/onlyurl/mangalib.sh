#!/usr/bin/env bash
set -e

which grep http pdfcpu fzf jo jq > /dev/null
if [[ ! "$1" =~ mangalib ]]; then
    jo result=notmine
    exit 0
fi

URL="$1" # E.g.: https://mangalib.me/ru/230767--my-co-worker-is-an-eldritch-being
URL="${URL%%\?*}" # Remove query part
DIR="$XDG_CACHE_HOME/uniplayer/mangalib"

mark() {
    while IF=$'\t' read -r VOLUME NUMBER REST; do
        MARK="(new)"
        if [[ -d "$1/$VOLUME/$NUMBER" ]]; then
            MARK="(cached)"
        fi

        printf "%s\t$VOLUME\t$NUMBER\t$REST\n" "$MARK"
    done
}

read -r DOMAIN < <(grep -Po '.+//[^/]+' <<< "$URL")
read -r REQNAME < <(grep -Po '.+//[^/]+/[^/]+/\K.+' <<< "$URL")
read -r NAME < <(http "https://api.cdnlibs.org/api/$REQNAME" \
    | jq -r .data.eng_name)

NAME="${NAME//\//-}"
IFS=$'\t' read -r MARKED VOLUME NUMBER STITLE < <(http "https://api.cdnlibs.org/api/$REQNAME/chapters" \
    | jq -r '.data[] | [.volume, .number, .name] | @tsv' \
    | mark "$DIR/$NAME" \
    | fzf)

STITLE="${STITLE//\//-}"
DIR="$DIR/$NAME/$VOLUME/$NUMBER"

mkdir -p "$DIR"

PDFFILE="$DIR/$NAME - $VOLUME-$NUMBER - $STITLE.pdf"
if [[ "$MARKED" != "(cached)" ]]; then
    read -r IMGTMPDIR < <(mktemp -d)

    FILES=()
    URLS=()
    while IFS=$'\t' read -r URL FILE; do
        FILES+=("$FILE")
        URLS+=("$URL")
    done < <(http "https://api.cdnlibs.org/api/$REQNAME/chapter?volume=$VOLUME&number=$NUMBER" \
        | jq --arg dir "$IMGTMPDIR" -r \
        '.data.pages[] | "https://img33.imgslib.link\(.url)\t\($dir)/\(.url | split("/")[-1])"')

    echo Mangalib: Extract pages... >&2
    parallel --colsep='\t' -kq http GET {1} "referer:$DOMAIN" -o {2} ::: "${URLS[@]}" :::+ "${FILES[@]}"
    echo Mangalib: Create pdf... >&2
    pdfcpu import -c disable "$PDFFILE" "${FILES[@]}" >&2
    echo Mangalib: Remove pages... >&2
    rm -r "$IMGTMPDIR"
fi

jo result=pdf url="$PDFFILE"
