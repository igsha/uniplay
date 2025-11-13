#!/usr/bin/env bash
set -e

which jq tr http parallel > /dev/null

mapfile -t JSON
SINGLEURL=1
URLS=()
if ! read -r URLS[0] < <(jq -r '.url // empty' <<< "${JSON[@]}"); then
    SINGLEURL=0
    readarray -t URLS < <(jq -r '.urls[]' <<< "${JSON[@]}")
    [[ "${#URLS[@]}" -gt 0 ]]
fi

if read -r REFERER < <(jq -r '.referer // empty' <<< "${JSON[@]}"); then
    REFERER="referer:$REFERER"
fi

read -r TDIR < <(mktemp -d -t uniplay.download.XXX)
echo "download: Download ${#URLS} files" >&2

mapfile -t FILES < <(parallel -k echo "$TDIR/{/}" '| tr -d "()"' ::: "${URLS[@]}")
parallel -kq http --follow --timeout 10 -o "{2}" GET "{1}" $REFERER ::: "${URLS[@]}" :::+ "${FILES[@]}"

export TDIR
if [[ "$SINGLEURL" -eq 1 ]]; then
    jq --arg url "${FILES[0]}" '.url="$url" | .dir=env.TDIR'
else
    read -r URLS < <(jo -a "${FILES[@]}")
    jq --argjson urls "$URLS" '.urls=$urls | .dir=env.TDIR'
fi <<< "${JSON[@]}"
