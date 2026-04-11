#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq jo > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .url \
    | read -r URL

getchapters() {
    DESCURL="https://rutube.ru/api/video/$1"
    echo "rutube: Extract description $DESCURL" >&2
    http GET "$DESCURL" \
        | jq '(.duration|tonumber) * 1000 as $dur | .description | [
                capture("(?:(?<h>\\d+):)?(?<m>\\d+):(?<s>\\d+) (?<t>.+)"; "g")
            ] | map(
                .tt=1000 * ((.h//0|tonumber) * 3600 + (.m|tonumber) * 60 + (.s|tonumber))
            ) | [
                .,
                .[1:] + [{tt: $dur}]
            ] | transpose | map({
                start: .[0].tt,
                end: .[1].tt,
                text: .[0].t}) | if length > 1 then {chapters: .} else {} end'
}

echo "rutube: Get url $URL" >&2
if [[ "$URL" =~ rutube\.ru/video/([0-9a-z]+)/? ]]; then
    VIDEOID="${BASH_REMATCH[1]}"
    URL="https://rutube.ru/api/play/options/$VIDEOID"

    echo "rutube: Extract options $URL" >&2
    http GET "$URL" \
        | jq -r '.video_balancer.m3u8, .title' \
        | { read -r URL; read -r TITLE; }

    echo "rutube: Extract m3u8 $URL" >&2
    http GET "$URL" \
        | mapfile M3U8

    <<< "${M3U8[@]}" rg 'RESOLUTION=(\d+)x(\d+)' -or $'$1\t$2' \
        | sort -run \
        | tee >(awk -F$'\t' '{printf "rutube: Available resolution %dx%d\n", $1, $2}' >&2) \
        | head -1 \
        | IFS=$'\t' read -r WIDTH HEIGHT

    echo "rutube: Select ${WIDTH}x${HEIGHT} resolution" >&2
    <<< "${M3U8[@]}" awk "/RESOLUTION=${WIDTH}x${HEIGHT}/{getline; print}" \
        | tee >(awk '{printf "rutube: Available server %s\n", $0}' >&2) \
        | head -1 \
        | read -r URL

    echo "rutube: Select server $URL" >&2
    getchapters "$VIDEOID" \
        | jo -f - url="$URL" title="$TITLE" type=video
else
    if [[ "$URL" =~ https://rutube\.ru/(u|channel)/([^/]+)/?([^/]+)?/? ]]; then
        BRANCH="${BASH_REMATCH[1]}"
        USERID="${BASH_REMATCH[2]}"
        FOLDER=${BASH_REMATCH[3]:-videos}
        if [[ "$BRANCH" != channel ]]; then
            http --follow GET "$URL" \
                | grep -Po '"userChannelId":\K\d+' \
                | head -1 \
                | read -r USERID
        fi

        echo "rutube: user=$USERID folder=$FOLDER" >&2
        if [[ "$FOLDER" == videos ]]; then
            URL="https://rutube.ru/api/video/person/$USERID/?origin__type=rtb,rst,ifrm,rspa"
        elif [[ "$FOLDER" == playlists ]]; then
            URL="https://rutube.ru/api/playlist/user/$USERID"
        elif [[ "$FOLDER" == shorts ]]; then
            URL="https://rutube.ru/api/video/person/$USERID/?origin__type=rshorts"
        fi
    fi

    if [[ "$URL" =~ /plst/([0-9]+)/? ]]; then
        URL="https://rutube.ru/api/playlist/custom/${BASH_REMATCH[1]}/videos"
    fi

    if [[ "$URL" =~ rshorts ]]; then
        ITEMURL="https://rutube.ru/shorts/"
    elif [[ "$URL" =~ /playlist/user/ ]]; then
        ITEMURL="https://rutube.ru/plst/"
    else
        ITEMURL="https://rutube.ru/video/"
    fi

    echo "rutube: List $URL" >&2
    http GET "$URL" \
        | jq -r --arg itemurl "$ITEMURL" '.next as $next | .results | {
            list: map({
                url: $itemurl + "\(.id)",
                title})
                + [select($next != null) | {url: $next, title: "###next###"}],
            hashkey: "url",
            type: "selectable",
            title: "rutube"}'
fi
