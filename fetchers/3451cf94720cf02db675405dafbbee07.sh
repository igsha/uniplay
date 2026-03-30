#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item | read -r URL

if [[ "$URL" =~ proxy=([^&]+) ]]; then
    USE_PROXY="${BASH_REMATCH[1]}"
fi

if [[ "$URL" =~ tags=([^&]+) || "$URL" =~ /videos ]]; then
    echo "3451cf94720cf02db675405dafbbee07: List $URL" >&2
    <<< "${JSON[@]}" "$UNIPLAY" -f 3451cf94720cf02db675405dafbbee07-list \
        | jq -r .item \
        | read -r URL
fi

jo result=url item="$URL" \
    | "$UNIPLAY" -f 3451cf94720cf02db675405dafbbee07-item \
    | jq --arg proxy "$USE_PROXY" 'if $proxy != "" then .proxy=$proxy end' \
    | "$UNIPLAY" -f mpv
