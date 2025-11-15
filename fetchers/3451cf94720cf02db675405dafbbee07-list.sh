#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq jo awk > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item | read -r URL
<<< "$URL" awk -F/ '{gsub("www.", ""); print $3}' | read -r DOMAIN

if [[ "$URL" =~ tags=([^&]+) ]]; then
    URL="https://api.${DOMAIN}/videos?tags=${BASH_REMATCH[1]}&sort=date"
elif [[ "$URL" =~ /videos ]]; then
    URL="https://api.${DOMAIN}/videos?rating=all&sort=date&limit=32"
fi

echo "3451cf94720cf02db675405dafbbee07-list: List $URL" >&2
BASEURL="$URL&page="
export VIDEOBASEURL="https://${DOMAIN}/video/"
declare -i PAGENUM="0"
URL="${BASEURL}$PAGENUM"
while [[ "$URL" =~ "$BASEURL" ]]; do
    PAGENUM+=1
    export NEXTURL="${BASEURL}$PAGENUM"
    http GET "$URL" "referer:https://$DOMAIN" \
        | jq '{items: (.results | map(env.VIDEOBASEURL + .id)) + [env.NEXTURL],
               names: (.results | map(.title)) + ["###next###"],
               title: "3451cf94720cf02db675405dafbbee07"}' \
        | "$UNIPLAY" -f marksel \
        | jq -r .item \
        | read -r URL
done

jo result=url item="$URL"
