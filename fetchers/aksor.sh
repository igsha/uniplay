#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http >/dev/null

mapfile JSON
<<< "${JSON[@]}" jq -r .url \
    | read -r URL

if [[ ! "$URL" =~ /api/video && "$URL" =~ (https?://[^/]+)/(video/[a-z0-9]+) ]]; then
    URL="${BASH_REMATCH[1]}/api/${BASH_REMATCH[2]}"
fi

{
    http GET "$URL" \
        | jq -r '{
            url: (.qualities | with_entries(select(.value != null)) | .q4k // .q2k // .q1080 // .q720 // .q480 // .q360),
            title: "\(.studio_name) - \(.episode)",
            type: "video"
        }'
    <<< "${JSON[@]}" jq 'del(.url)'
} | jq -s add
