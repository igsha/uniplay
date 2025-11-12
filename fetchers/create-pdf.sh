#!/usr/bin/env bash
set -e
shopt -s lastpipe

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.urls[]' \
    | mapfile -t URLS

FILES=()
declare -i TW=0 ACCH=0
magick identify -format $'%w\t%h\t%i\n' "${URLS[@]}" | while IFS=$'\t' read -r W H N; do
    ACCH+="$H"
    FILES+=("$N")
    if ((TW < W)); then
        TW=$W
    fi
done

# Golden ratio
TH=$((TW * 6765/4181))
echo "create-pdf: Crop images to ${TW}x$TH" >&2

mktemp -d -t uniplay.create-pdf.XXX \
    | read -r TDIR
trap "rm -r \"$TDIR\"" INT EXIT
echo "create-pdf: Use temp dir $TDIR" >&2

# memory exhaustive method
magick \( "${FILES[@]}" -gravity center -append \) +repage -crop "${TW}x$TH" "$TDIR/uniplay.create-pdf.cropped.%04d.jpg"
find "$TDIR" -name 'uniplay.create-pdf.cropped.*.jpg' -print \
    | tac \
    | mapfile -t RESULT

# fix last image height
if ((ACCH % TH != 0)); then
    magick identify -format "create-pdf: Fix last image %i %Wx%H -> ${TW}x$TH\n" "${RESULT[@]: -1:1}" >&2
    magick "${RESULT[@]: -1:1}" -gravity north -extent "${TW}x$TH" "${RESULT[@]: -1:1}"
fi

mktemp -u -t uniplay.create-pdf.XXX.pdf \
    | read -r PDFFILE

export PDFFILE
pdfcpu import -c disable "$PDFFILE" "${RESULT[@]}" >&2

<<< "${JSON[@]}" jq 'del(.urls) | .url=env.PDFFILE | .result="pdf" | .istemp=true'
