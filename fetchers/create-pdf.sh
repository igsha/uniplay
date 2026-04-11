#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo magick pdfcpu tac > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.list[] | .file' \
    | mapfile -t FILES

[[ "${#FILES[@]}" -gt 0 ]]

FILENAMES=()
declare -i TW=0 ACCH=0
magick identify -format $'%w\t%h\t%i\n' "${FILES[@]}" | while IFS=$'\t' read -r W H N; do
    ACCH+="$H"
    FILENAMES+=("$N")
    if ((TW < W)); then
        TW=$W
    fi
done

# Golden ratio
TH=$((TW * 6765/4181))
echo "create-pdf: Crop images to ${TW}x$TH" >&2

mktemp -d -t uniplay.create-pdf.images.XXX \
    | read -r TDIR
trap "rm -r \"$TDIR\"" INT EXIT

# memory exhaustive method
magick \( "${FILENAMES[@]}" -gravity center -append \) +repage -crop "${TW}x$TH" "$TDIR/uniplay.create-pdf.cropped.%04d.jpg"
find "$TDIR" -name 'uniplay.create-pdf.cropped.*.jpg' -print \
    | tac \
    | mapfile -t RESULT

# fix last image height
if ((ACCH % TH != 0)); then
    magick identify -format "create-pdf: Fix last image %i %Wx%H -> ${TW}x$TH\n" "${RESULT[@]: -1:1}" >&2
    magick "${RESULT[@]: -1:1}" -gravity north -extent "${TW}x$TH" "${RESULT[@]: -1:1}"
fi

mktemp -d -t uniplay.create-pdf.XXX \
    | read -r PDFDIR

if ! <<< "${JSON[@]}" jq -r '.title // empty' | read -r TITLE; then
    mktemp -u -t uniplay.create-pdf.XXX \
        | read -r TITLE
fi

PDFFILE="$PDFDIR/${TITLE//\//-}.pdf"

pdfcpu import -c disable "$PDFFILE" "${RESULT[@]}" >&2

jo file="$PDFFILE" delete="$PDFDIR" type=pdf
