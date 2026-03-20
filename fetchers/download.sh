#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo tr http parallel > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.item // .items[]' | readarray -t URLS
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

parallel -k echo "$TDIR/{/}" '| tr -d "()"' ::: "${URLS[@]}" \
    | mapfile -t FILES
parallel -kqj "${PARLEVEL}" http --follow --timeout "$HTTPTIMEOUT" -o "{2}" GET "{1}" $REFERER ::: "${URLS[@]}" :::+ "${FILES[@]}"

jo -a "${FILES[@]}" \
    | jo result=files items=:- delete="$TDIR"
