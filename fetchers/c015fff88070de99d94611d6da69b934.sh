#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq > /dev/null

mapfile -t JSON
jq -r .url <<< "${JSON[@]}" | read -r URL
if [[ "$URL" =~ ([^:]+)://(.+) && "${BASH_REMATCH[1]:0:4}" != http ]]; then
    URL="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    jq --arg url "$URL" '.url=$url' <<< "${JSON[@]}" | mapfile -t JSON
fi
echo "c015fff88070de99d94611d6da69b934: Extract $URL" >&2

<<< "${JSON[@]}" "$UNIPLAY" -f ralode \
    | "$UNIPLAY" -f iframe \
    | "$UNIPLAY" -f videoplayer \
    | jq '.url=(.urls | map(select(test("premium") | not)) | .[-1]) | .result="url"' \
    | "$UNIPLAY" -f mpv
