#!/usr/bin/env bash
set -e

which grep http pdfcpu fzf xdg-open > /dev/null

URL="$1" # E.g.: https://mangalib.me/ru/230767--my-co-worker-is-an-eldritch-being
URL="${URL%%\?*}" # Remove query part

read -r DOMAIN < <(grep -Po '.+//[^/]+' <<< "$URL")
read -r REQNAME < <(grep -Po '.+//[^/]+/[^/]+/\K.+' <<< "$URL")
read -r NAME < <(http "https://api.cdnlibs.org/api/$REQNAME" \
    | jq -r .data.eng_name \
    | sed 's;/;-;g')

read -r QUERY < <(http "https://api.cdnlibs.org/api/$REQNAME/chapters" \
    | jq -r '.data[] | "\(.volume)-\(.number) \(.name)"' \
    | fzf \
    | sed 's/\([0-9]\+\)-\([0-9]\+\).*/volume=\1\&number=\2/')

read -r DIR < <(mktemp -d)
echo "Tempdir $DIR"

http "https://api.cdnlibs.org/api/$REQNAME/chapter?$QUERY" \
    | jq -r '.data.pages[] | "https://img33.imgslib.link\(.url)"' \
    | parallel -k http GET "{1}" "referer:$DOMAIN" -o "$DIR/{1/}" '&&' echo "$DIR/{1/}" \
    | xargs pdfcpu import "$DIR/$NAME.pdf"

xdg-open "$DIR/$NAME.pdf"
rm -r "$DIR"
