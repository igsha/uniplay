#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq xq tee sed > /dev/null

jq -r .url \
    | read -r URL

http --follow GET "$URL" \
    | mapfile HTML

if [[ "$URL" =~ /movie/[0-9]+ ]]; then
    echo "18066364c58e180eac6dc071a79f58f7: Extract $URL" >&2
    <<< "${HTML[@]}" htmlq 'head > title, div#player_div div.quality_chooser' \
        | sed -e '1i<div>' -e '$a</div>' \
        | xq -r '.div | {title, list: .div.a | map({url: .["@href"], quality: .["#text"]}) | reverse}' \
        | tee >(jq -r '.list[] | "18066364c58e180eac6dc071a79f58f7: [\(.quality)] \(.url)"' >&2) \
        | jq '{url: .list | map(select(.url | startswith("https://lolo") | not)) | .[0].url, title, type: "video"}'
else
    echo "18066364c58e180eac6dc071a79f58f7: List $URL" >&2
    <<< "${HTML[@]}" htmlq "ul.videos_ul a" --remove-nodes img \
        | sed -e '1i<div>' -e '$a</div>' \
        | xq '.div.a | {list: map({url: .["@href"], title: .p}), title: "18066364c58e180eac6dc071a79f58f7", type: "selectable", hashkey: "url"}'
fi
