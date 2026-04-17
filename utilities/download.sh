#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo tr http parallel xargs basename > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.list[] | .url' | readarray -t URLS
if [[ "${#URLS[@]}" -eq 0 ]]; then
    echo "download: No urls" >&2
    exit 1
fi

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
    echo "download: Use referer $REFERER" >&2
fi
if ! <<< "${JSON[@]}" jq -r '.parallel // empty' | read -r PARLEVEL; then
    PARLEVEL=0
fi
if ! <<< "${JSON[@]}" jq -r '.timeout // empty' | read -r HTTPTIMEOUT; then
    HTTPTIMEOUT=30
fi

mktemp -d -t uniplay.download.XXX \
    | read -r TDIR
echo "download: Download ${#URLS[@]} files to $TDIR" >&2
echo "download: Use timeout=$HTTPTIMEOUT parallel=$PARLEVEL" >&2

<<< "${JSON[@]}" jq -r '(.list[] | .title) // empty' | readarray -t TITLES
if [[ "${#TITLES[@]}" -eq 0 ]]; then
    echo "download: No titles, use urls to determine filenames" >&2
    printf "%s\n" "${URLS[@]}" \
        | xargs basename -a \
        | tr -d "()" \
        | readarray -t TITLES
fi

FILES=("${TITLES[@]/#/$TDIR/}")

parallel -kqj "${PARLEVEL}" http --follow --timeout "$HTTPTIMEOUT" -o "{2}" GET "{1}" $REFERER ::: "${URLS[@]}" :::+ "${FILES[@]}"

{
    <<< "${JSON[@]}" jq 'del(.list)'
    jo -a "${FILES[@]}" \
        | jq '{list: map({file:.})}'
    jo delete="$TDIR" type=file
} | jq -s add
