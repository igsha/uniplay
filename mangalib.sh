#!/usr/bin/env bash
set -e

which grep http pdfcpu fzf xdg-open > /dev/null

URL="$1" # E.g.: https://mangalib.me/ru/230767--my-co-worker-is-an-eldritch-being
URL="${URL%%\?*}" # Remove query part
DIR="$XDG_CACHE_HOME/mangalib"

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
    | jq -r '.data[] | "\(.volume)\t\(.number)\t\(.name)"' \
    | mark "$DIR/$NAME" \
    | fzf)

STITLE="${STITLE//\//-}"
DIR="$DIR/$NAME/$VOLUME/$NUMBER"

mkdir -p "$DIR"

PDFFILE="$DIR/$NAME - $VOLUME-$NUMBER - $STITLE.pdf"
if [[ "$MARKED" != "(cached)" ]]; then
    mapfile -t < <(http "https://api.cdnlibs.org/api/$REQNAME/chapter?volume=$VOLUME&number=$NUMBER" \
        | jq -r '.data.pages[] | "https://img33.imgslib.link\(.url)\t'"$DIR/"'\(.url | split("/")[-1])"')

    parallel --colsep='\t' -kq http GET {1} "referer:$DOMAIN" -o {2} ::: "${MAPFILE[@]}"
    pdfcpu import -c disable "$PDFFILE" "${MAPFILE[@]##*$'\t'}"
    rm "${MAPFILE[@]##*$'\t'}"
fi

xdg-open "$PDFFILE"
