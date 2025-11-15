#!/usr/bin/env bash
set -e
shopt -s lastpipe

which grep http jq jo sha1sum awk > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item | read -r URL
<<< "$URL" awk -F/ '{gsub("www.", ""); print $3}' | read -r DOMAIN

[[ "$URL" =~ /video/([A-Za-z0-9]+) ]]
URL="https://api.${DOMAIN}/video/${BASH_REMATCH[1]}"

http GET "$URL" "referer:https://$DOMAIN" \
    | jq -r '"\(.fileUrl)\t\(.file.id)\t\(.title)"' \
    | IFS=$'\t' read -r FILEURL FILEID TITLE

echo "3451cf94720cf02db675405dafbbee07-item: Extracted $FILEURL..." >&2
<<< "$FILEURL" grep -Po 'expires=\K\d+' \
    | read -r EXPIRES

echo "3451cf94720cf02db675405dafbbee07-item: X-Version: ${FILEID}_${EXPIRES}_5nFp9kmbNnHdAFhaqMvt" >&2
printf "%s_%d_5nFp9kmbNnHdAFhaqMvt" "$FILEID" "$EXPIRES" \
    | sha1sum \
    | awk '{print $1}' \
    | read -r XVERSION

http GET "$FILEURL" "x-version:$XVERSION" \
    | jq -r '.[] | select(.name == "Source") | .src.view | sub("^//"; "https://")' \
    | read -r URL

echo "3451cf94720cf02db675405dafbbee07: Trying $URL..." >&2
if ! http -hq --check-status --timeout=2.4 GET "$URL" 2>/dev/null; then
    SERVERS=(pela silverwolf mikoto)
    for ((i=0; i<${#SERVERS[@]}; ++i)); do
        <<< "$URL" awk -F/ 'gsub($3,"'${SERVERS[$i]}.${DOMAIN}'",$0)' \
            | read -r URL

        echo "3451cf94720cf02db675405dafbbee07: Trying $URL..." >&2
        if http -hq --check-status --timeout=2.1 GET "$URL" 2>/dev/null; then
            break
        fi
    done
fi

jo result=url title="$TITLE" item="$URL"
