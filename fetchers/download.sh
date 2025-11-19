#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo tr http parallel > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.item // .items[]' | readarray -t URLS
[[ "${#URLS[@]}" -gt 0 ]]

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    REFERER="referer:$REFERER"
fi

mktemp -d -t uniplay.download.XXX \
    | read -r TDIR
echo "download: Download ${#URLS[@]} files" >&2

parallel -k echo "$TDIR/{/}" '| tr -d "()"' ::: "${URLS[@]}" \
    | mapfile -t FILES
parallel -kq http --follow --timeout 10 -o "{2}" GET "{1}" $REFERER ::: "${URLS[@]}" :::+ "${FILES[@]}"

jo -a "${FILES[@]}" \
    | jo result=files items=:- delete="$TDIR"
