#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.url, (.url | split("/")[2] | split(".")[-2:] | join("."))' \
    | { read -r URL; read -r SERVER; }

if [[ "$URL" =~ tags=([^&]+) || "$URL" =~ /videos ]]; then
    TAGS="${BASH_REMATCH[1]}"
    echo "3451cf94720cf02db675405dafbbee07: List $URL" >&2

    if [[ "$URL" =~ proxy=([^&]+) ]]; then
        USE_PROXY="${BASH_REMATCH[1]}"
        echo "3451cf94720cf02db675405dafbbee07: Save proxy=$USE_PROXY from url" >&2
    elif <<< "${JSON[@]}" jq -r '.proxy // empty' | read -r JSON_PROXY; then
        USE_PROXY="$JSON_PROXY"
    fi

    PAGENUM=0
    if [[ "$URL" =~ page=([0-9]+) ]]; then
        PAGENUM="${BASH_REMATCH[1]}"
    fi

    if [[ -n "$TAGS" ]]; then
        URL="https://apiq.${SERVER}/videos?tags=${TAGS}&sort=date"
    else
        URL="https://apiq.${SERVER}/videos?rating=all&sort=date&limit=32"
    fi

    NEXTURL="$URL&page=$((PAGENUM+1))"
    http GET "$URL&page=$PAGENUM" "referer:https://$SERVER" \
        | jq --arg nexturl "$NEXTURL" --arg server "$SERVER" '.results | {
            list: map({
                url: "https://\($server)/video/\(.id)",
                title: .title
            }) + [{
                url: $nexturl,
                title: "###next###"
            }],
            hashkey: "url",
            type: "selectable",
            title: "3451cf94720cf02db675405dafbbee07"}' \
        | jq --arg proxy "$USE_PROXY" 'if $proxy != "" then .proxy=$proxy end'

elif [[ "$URL" =~ /video/([A-Za-z0-9]+) ]]; then
    URL="https://apiq.${SERVER}/video/${BASH_REMATCH[1]}"

    echo "3451cf94720cf02db675405dafbbee07: Extract video from $URL" >&2
    http GET "$URL" "referer:https://$SERVER" \
        | jq -r '[.fileUrl, .file.id, .title] | @tsv' \
        | IFS=$'\t' read -r FILEURL FILEID TITLE

    echo "3451cf94720cf02db675405dafbbee07: Extracted $FILEURL" >&2
    <<< "$FILEURL" grep -Po 'expires=\K\d+' \
        | read -r EXPIRES

    printf "%s_%s_%s" "$FILEID" "${EXPIRES}" "mSvL05GfEmeEmsEYfGCnVpEjYgTJraJN" \
        | tee >(xargs printf "3451cf94720cf02db675405dafbbee07: X-Version=%s\n" >&2) \
        | sha1sum \
        | cut -c -40 \
        | tee >(xargs printf "3451cf94720cf02db675405dafbbee07: Converted X-Version=%s\n" >&2) \
        | read -r XVERSION

    http GET "$FILEURL" "x-version:$XVERSION" \
        | jq -r '.[] | select(.name == "Source") | .src.view | sub("^//"; "https://")' \
        | read -r URL

    echo "3451cf94720cf02db675405dafbbee07: Trying $URL" >&2
    if ! http -hq --check-status --timeout=4.4 GET "$URL" 2>/dev/null; then
        SERVERS=(pela silverwolf mikoto)
        for ((i=0; i<${#SERVERS[@]}; ++i)); do
            <<< "$URL" awk -F/ 'gsub($3,"'${SERVERS[$i]}.${SERVER}'",$0)' \
                | read -r URL

            echo "3451cf94720cf02db675405dafbbee07: Trying $URL" >&2
            if http -hq --check-status --timeout=4.1 GET "$URL" 2>/dev/null; then
                break
            fi
        done
    fi

    { printf "%s" "${JSON[@]}"; jo url="$URL" title="$TITLE" type=video; } | jq -s add
else
    echo "3451cf94720cf02db675405dafbbee07: Unsupported url $URL" >&2
    exit 1
fi
