#!/usr/bin/env bash
set -e

which grep http pdfcpu fzf jo jq > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")

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

NAME="${REQNAME//\//-}"
IFS=$'\t' read -r MARKED VOLUME NUMBER STITLE < <(http GET "https://api.cdnlibs.org/api/$REQNAME/chapters" \
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
    done < <(http GET "https://api.cdnlibs.org/api/$REQNAME/chapter?volume=$VOLUME&number=$NUMBER" \
        | jq --arg dir "$IMGTMPDIR" -r \
        '.data.pages[] | "https://img33.imgslib.link\(.url)\t\($dir)/\(.url | split("/")[-1])"')

    echo Mangalib: Extract pages... >&2
    parallel --colsep='\t' -kq http GET {1} "referer:$DOMAIN" -o {2} ::: "${URLS[@]}" :::+ "${FILES[@]}"
    echo Mangalib: Create pdf... >&2
    pdfcpu import -c disable "$PDFFILE" "${FILES[@]}" >&2
    echo Mangalib: Remove pages... >&2
    rm -r "$IMGTMPDIR"
fi

export PDFFILE
<<< "${JSON[@]}" jq '.result="pdf" | .url=env.PDFFILE' | "$UNIPLAY" -f pdf
