#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http rg sort head awk > /dev/null

mapfile -t JSON
jq -r .item <<< "${JSON[@]}" | read -r URL

[[ "$URL" =~ [^/]+://[^/]+/[^/]+/([0-9a-z]+)/? ]]
URL="https://rutube.ru/api/play/options/${BASH_REMATCH[1]}"

echo "rutube-video: Extract $URL" >&2
http GET "$URL" \
    | jq -r '[.video_balancer.m3u8, .title] | @tsv' \
    | IFS=$'\t' read -r URL TITLE

echo "rutube-video: Extract m3u8 $URL" >&2
http GET "$URL" | mapfile M3U8

<<< "${M3U8[@]}" \
    rg 'RESOLUTION=(\d+)x(\d+)' -or $'$1\t$2' \
    | sort -run \
    | tee >(awk -F$'\t' '{printf "rutube-video: Available resolution %dx%d\n", $1, $2}' >&2) \
    | head -1 \
    | IFS=$'\t' read -r WIDTH HEIGHT

echo "rutube-video: Select ${WIDTH}x${HEIGHT} resolution" >&2
<<< "${M3U8[@]}" \
    awk "/RESOLUTION=${WIDTH}x${HEIGHT}/{getline; print}" \
    | tee >(awk '{printf "rutube-video: Available server %s\n", $0}' >&2) \
    | head -1 \
    | read -r URL

echo "rutube-video: Select server $URL" >&2
export URL TITLE
<<< "${JSON[@]}" \
    jq '.item=env.URL | .title=env.TITLE' \
    | "$UNIPLAY" -f mpv
