#!/usr/bin/env bash
set -e

which grep http jq jo sha1sum awk fzf cksum > /dev/null

read -r DOMAIN < <(awk -F/ '{gsub("www.", ""); print $3}' <<< "$1")
read -r HASHNAME < <(awk -F. '{print $(NF-1)}' <<< "$DOMAIN" | md5sum | cut -c -32)
if [[ ! "$HASHNAME" == 3451cf94720cf02db675405dafbbee07 ]]; then
    jo result=notmine
    exit 0
fi

choice() {
    ID=next
    TITLE="0"
    while [[ "$ID" == next ]]; do
        URL="${1}&page=$TITLE"
        PAGENUM=$((TITLE+1))
        IFS=$'\t' read -r TITLE ID < <(http GET "$URL" \
            | jq -r '(.results + [{title: "'$PAGENUM'", id: "next"}]) | .[] | [.title, .id] | @tsv' \
            | fzf)
    done

    export TITLE ID
}

if [[ "$1" =~ tags=([^&]+) ]]; then
    choice "https://api.${DOMAIN}/videos?tags=${BASH_REMATCH[1]}&sort=date"
elif [[ "$1" =~ /video/([^/]+) ]]; then
    ID="${BASH_REMATCH[1]}"
elif [[ "$1" =~ /videos ]]; then
    choice "https://api.${DOMAIN}/videos?rating=all&sort=date&limit=32"
else
    echo "3451cf94720cf02db675405dafbbee07: Unknown url $1" >&2
    exit 1
fi

IFS=$'\t' read -r FILEURL FILEID TITLE < <(http GET "https://api.${DOMAIN}/video/$ID" \
    | jq -r '"\(.fileUrl)\t\(.file.id)\t\(.title)"')

echo "3451cf94720cf02db675405dafbbee07: Extracted $FILEURL..." >&2
read -r EXPIRES < <(grep -Po 'expires=\K\d+' <<< "$FILEURL")
echo "3451cf94720cf02db675405dafbbee07: X-Version: ${FILEID}_${EXPIRES}_5nFp9kmbNnHdAFhaqMvt" >&2
read -r XVERSION < <(printf "%s_%d_5nFp9kmbNnHdAFhaqMvt" "$FILEID" "$EXPIRES" \
    | sha1sum \
    | awk '{print $1}')

read -r URL < <(http GET "$FILEURL" "x-version:$XVERSION" \
    | jq -r '.[] | select(.name == "Source") | .src.view | sub("^//"; "https://")')

echo "3451cf94720cf02db675405dafbbee07: Trying $URL..." >&2
if ! http -hq --check-status --timeout=2.4 GET "$URL" 2>/dev/null; then
    SERVERS=(pela silverwolf)
    for ((i=0; i<${#SERVERS[@]}; ++i)); do
        read -r URL < <(awk -F/ 'gsub($3,"'${SERVERS[$i]}.${DOMAIN}'",$0)' <<< "$URL")
        echo "3451cf94720cf02db675405dafbbee07: Trying $URL..." >&2
        if http -hq --check-status --timeout=2.1 GET "$URL" 2>/dev/null; then
            break
        fi
    done
fi

jo result=video title="$TITLE" url="$URL"
