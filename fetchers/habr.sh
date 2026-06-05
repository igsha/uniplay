#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq http sed htmlq pandoc wkhtmltopdf jo >/dev/null

jq -r .url \
    | read -r URL

echo "habr: Extract $URL" >&2
http GET "$URL" \
    | htmlq .tm-misprint-area \
    | {
        echo "<head><style>img {
                max-width: 100%;
                height: auto;
        }
        </style></head>"
        sed -e 's;src="//;src="https://;g'
    } \
    | sed -E 's;(<img[^>]+height=")[^"]+;\1auto;g' \
    | mapfile HTML

mktemp -u -t uniplay.habr.XXX.pdf \
    | read -r TMPHABRPDF

echo "habr: Convert to pdf $TMPHABRPDF" >&2
<<< "${HTML[@]}" pandoc -f html -t pdf -s --reference-links \
    -V margin-top=10 -V margin-left=10 -V margin-right=10 -V margin-bottom=10 -V "maxwidth:100%" -V papersize=a4 -V fontsize=1.5em \
    --pdf-engine=wkhtmltopdf -o "$TMPHABRPDF"

jo file="$TMPHABRPDF" delete="$TMPHABRPDF" type=pdf
