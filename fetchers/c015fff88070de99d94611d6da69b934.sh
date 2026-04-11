#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .url \
    | read -r URL

if [[ "$URL" =~ /video.php\?id=[0-9]+ ]]; then
    echo "c015fff88070de99d94611d6da69b934: Extract video from $URL" >&2
    <<< "${JSON[@]}" "$UNIPLAY" iframe \
        | "$UNIPLAY" videoplayer \
        | jq '.url=(.list | map(.url | select(test("premium") | not)) | .[-1]) | del(.list) | .type="video"'
else
    echo "c015fff88070de99d94611d6da69b934: List videos $URL" >&2
    <<< "${JSON[@]}" "$UNIPLAY" ralode \
        | jq '.list |= reverse | .title="c015fff88070de99d94611d6da69b934" | .type="selectable"'
fi
