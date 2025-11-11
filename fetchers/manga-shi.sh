#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq sed htmlq fzf tr parallel pdfcpu sqlite3 > /dev/null

mapfile -t JSON
printf "%s\n" "${JSON[@]}" \
    | jq -r .url \
    | read -r URL

DB="$XDG_CACHE_HOME/uniplay.db"
TBLNAME="${URL%/}"
TBLNAME="${TBLNAME##*/}"

mktemp -d -t uniplay.manga-shi.XXX \
    | read -r TDIR
trap "rm -r \"$TDIR\"" INT EXIT
echo "manga-shi: Set downloading dir $TDIR" >&2

REGISTER="$TDIR/register.html"

echo "manga-shi: Download chapters ${URL%/}/ajax/chapters" >&2
http POST "${URL%/}/ajax/chapters" > "$REGISTER"

< "$REGISTER" htmlq 'li a' -t \
    | sed '/^$/d;s/^[[:blank:]]*//;s/[[:blank:]]*$//' \
    | mapfile -t NAMES

< "$REGISTER" htmlq 'li a' -a href \
    | mapfile -t URLS

echo "manga-shi: Find info from [$TBLNAME] of $DB" >&2
sqlite3 "$DB" "create table if not exists '$TBLNAME' (name str);" >&2
sqlite3 "$DB" "select name from '$TBLNAME';" \
    | mapfile -t NAMESINTABLE

for i in "${!URLS[@]}"; do
    MARK="(new)"
    if [[ " ${NAMESINTABLE[*]} " =~ " ${NAMES[$i]} " ]]; then
        MARK="(cached)"
    fi

    printf '%s\t%s\t%s\n' "$MARK" "${NAMES[$i]}" "${URLS[$i]}"
done \
    | fzf -d $'\t' --with-nth=1,2 --accept-nth=2,3 \
    | IFS=$'\t' read -r NAME URL

echo "manga-shi: Download chapter $URL" >&2
http --follow GET "$URL" > "$REGISTER"

< "$REGISTER" htmlq 'head > title' -t \
    | tr '/' '-' \
    | read -r TITLE

URLS=()
FILES=()
< "$REGISTER" htmlq '.reading-content div > img' -a data-src \
    | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' \
    | while read -r URL; do
        URLS+=("$URL")
        FILES+=("$TDIR/${URL##*/}")
    done

echo "manga-shi: Download ${#URLS[@]} files" >&2
parallel -q http --follow GET "{1}" -o "{2}" ::: "${URLS[@]}" :::+ "${FILES[@]}"

export PDFFILE="$TDIR/${TITLE}.pdf"
echo "manga-shi: Create pdf $PDFFILE" >&2
pdfcpu import -c disable "$PDFFILE" "${FILES[@]}" >&2

echo "manga-shi: Update db" >&2
sqlite3 "$DB" "insert into '$TBLNAME' (name) values ('$NAME');" >&2

<<< "${JSON[@]}" jq '.result="pdf" | .url=env.PDFFILE' | "$UNIPLAY" -f pdf
