#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http pandoc >/dev/null

jq -r 'has("url"), .url // .file' \
    | { read -r ISURL; read -r ITEM; }

if [[ "$ISURL" == true ]]; then
    echo "ipynb: Download ipynb from $ITEM" >&2
    http GET "$ITEM" \
        | mapfile CONTENT
else
    echo "ipynb: Load ipynb from file $ITEM" >&2
    < "$ITEM" mapfile CONTENT
fi

mktemp -t uniplay.ipynb.XXX.pdf \
    | read -r PDFFILE

echo "ipynb: Convert ipynb into pdf $PDFFILE" >&2
<<< "${CONTENT[@]}" pandoc -f ipynb -t pdf --pdf-engine=typst -V "mainfont:DejaVu Serif" -o "$PDFFILE"
jo file="$PDFFILE" type=pdf delete="$PDFFILE"
