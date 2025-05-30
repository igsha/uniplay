#!/usr/bin/env bash
set -e

which grep http pdfcpu fzf xdg-open > /dev/null

URL="$1" # E.g.: https://mangalib.me/ru/230767--my-co-worker-is-an-eldritch-being
URL="${URL%%\?*}" # Remove query part
DIR="$XDG_CACHE_HOME/mangalib"

mark() {
    while IF=$'\t' read -r VOLUME NUMBER REST; do
        printf "$VOLUME\t$NUMBER\t$REST"
        if [[ -d "$1/$VOLUME/$NUMBER" ]]; then
            printf "\t*"
        fi

        printf "\n"
    done
}

read -r DOMAIN < <(grep -Po '.+//[^/]+' <<< "$URL")
read -r REQNAME < <(grep -Po '.+//[^/]+/[^/]+/\K.+' <<< "$URL")
read -r NAME < <(http "https://api.cdnlibs.org/api/$REQNAME" \
    | jq -r .data.eng_name)

NAME="${NAME//\//-}"
IFS=$'\t' read -r VOLUME NUMBER STITLE MARKED < <(http "https://api.cdnlibs.org/api/$REQNAME/chapters" \
    | jq -r '.data[] | "\(.volume)\t\(.number)\t\(.name)"' \
    | mark "$DIR/$NAME" \
    | fzf)

STITLE="${STITLE//\//-}"
DIR="$DIR/$NAME/$VOLUME/$NUMBER"

mkdir -p "$DIR"

PDFFILE="$DIR/$NAME - $STITLE.pdf"
if [[ -z "$MARKED" ]]; then
    http "https://api.cdnlibs.org/api/$REQNAME/chapter?volume=$VOLUME&number=$NUMBER" \
        | jq -r '.data.pages[] | "https://img33.imgslib.link\(.url)"' \
        | parallel -k http GET {1} "referer:$DOMAIN" -o \"$DIR/{1/}\" '&&' printf \"$DIR/{1/}\\0\" \
        | xargs -0 pdfcpu import -c disable "$PDFFILE"
fi

xdg-open "$PDFFILE"
