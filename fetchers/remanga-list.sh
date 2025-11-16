#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq jo > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

[[ "$URL" =~ [^/]+//[^/]+/manga/([^/?&]+) ]]
REQNAME="${BASH_REMATCH[1]}"
export ORIGURL="${BASH_REMATCH[0]}/"

URL="https://api.remanga.org/api/v2/titles/$REQNAME/"
echo "remanga-list: Download list $URL" >&2
http GET "$URL" \
    | jq -r '"\(.secondary_name | sub("/"; "-"))\t\(.branches[0].id)"' \
    | IFS=$'\t' read -r TITLE BRANCHID

echo "remanga-list: Chapters for [$TITLE] [$BRANCHID]" >&2

BASEURL="https://api.remanga.org/api/v2/titles/chapters/?branch_id=$BRANCHID&ordering=-index&page="
declare -i PAGENUM="1"
URL="${BASEURL}$PAGENUM"
while [[ "$URL" =~ "$BASEURL" ]]; do
    PAGENUM+=1
    export NEXTURL="${BASEURL}$PAGENUM"
    http GET "$URL" \
        | jq '{items: (.results | map(env.ORIGURL + "\(.id)")) + [.next | select(. != null) | env.NEXTURL],
               names: (.results | map("\(.tome)-\(.chapter)-\(.name)")) + [.next | select(. != null) | "###next###"],
               title: "remanga"}' \
        | "$UNIPLAY" -f marksel \
        | jq -r .item \
        | read -r URL
done

jo result=url item="$URL"
