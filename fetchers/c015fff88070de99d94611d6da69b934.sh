#!/usr/bin/env bash
set -eo pipefail

which jq > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")
echo "c015fff88070de99d94611d6da69b934: Extract $URL" >&2

<<< "${JSON[@]}" "$UNIPLAY" -f ralode \
    | "$UNIPLAY" -f iframe \
    | "$UNIPLAY" -f videoplayer \
    | jq '.url=(.urls | map(select(test("premium") | not)) | .[-1]) | .result="url"' \
    | "$UNIPLAY" -f mpv
