#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http rg sort head awk > /dev/null

mapfile -t JSON
jq -r .item <<< "${JSON[@]}" | read -r URL

echo "rutube-video: Extract $URL" >&2

[[ "$URL" =~ [^/]+://[^/]+/[^/]+/([0-9a-z]+)/? ]]
VIDEOID="${BASH_REMATCH[1]}"
URL="https://rutube.ru/api/play/options/$VIDEOID"

echo "rutube-video: Extract options $URL" >&2
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

DESCURL="https://rutube.ru/api/video/$VIDEOID"
echo "rutube-video: Extract description $DESCURL" >&2
CHAPTERS=()
http GET "$DESCURL" \
    | jq -r '.duration,.description' \
    | {
        read -r DURATION

        LASTINDEX=0
        while read -r LINE; do
            if [[ "$LINE" =~ (([0-9]+):)?([0-9]{1,2}):([0-9]{2})[[:blank:]]*-?[[:blank:]]*(.+) ]]; then
                TEXT="${BASH_REMATCH[5]}"
                # remove leading zeros
                declare -i HH="${BASH_REMATCH[2]}" MM="${BASH_REMATCH[3]#0}" SS="${BASH_REMATCH[4]#0}"
                declare -i STARTTIME="$((1000 * (HH * 3600 + MM * 60 + SS)))"
                if [[ "$LASTINDEX" -gt 0 ]]; then
                    CHAPTERS["$LASTINDEX"]="$STARTTIME"
                    STARTTIME+=1
                fi

                CHAPTERS+=("$STARTTIME" "" "$TEXT")
                LASTINDEX=$((${#CHAPTERS[@]} - 2))
            fi
        done

        if [[ "$LASTINDEX" -gt 0 ]]; then
            CHAPTERS["$LASTINDEX"]="$((1000 * DURATION))"
        fi
    }

if [[ "${#CHAPTERS[@]}" -gt 0 ]]; then
    for ((i=0; i < ${#CHAPTERS[@]}; i+=3)); do
        jo start="${CHAPTERS[$i]}" end="${CHAPTERS[$((i+1))]}" text="${CHAPTERS[$((i+2))]}"
    done \
        | jo -a \
        | jo -e result=url item="$URL" title="$TITLE" chapters=:-
else
    jo -e result=url item="$URL" title="$TITLE"
fi
