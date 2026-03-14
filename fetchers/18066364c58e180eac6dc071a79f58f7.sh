#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq xq tee sed > /dev/null

jq -r '.item' \
    | read -r URL

if [[ "$URL" =~ /movie/[0-9]+ ]]; then
    echo "18066364c58e180eac6dc071a79f58f7: Extract $URL" >&2
    http --follow GET "$URL" \
        | htmlq 'head > title, div#player_div div.quality_chooser' \
        | sed -e '1i<div>' -e '$a</div>' \
        | xq -r '.div | {title: .title, items: .div.a | map({url: .["@href"], quality: .["#text"]}) | reverse}' \
        | tee >(jq -r '.items[] | "18066364c58e180eac6dc071a79f58f7: [\(.quality)] \(.url)"' >&2) \
        | jq '{item: .items[0].url, title: .title}' \
        | exec "$UNIPLAY" -f mpv
else
    echo "18066364c58e180eac6dc071a79f58f7: List $URL" >&2
    http --follow GET "$URL" \
        | htmlq "ul.videos_ul a" --remove-nodes img \
        | sed -e '1i<div>' -e '$a</div>' \
        | xq '.div.a | {items: map({item: .["@href"], name: .p}), title: "18066364c58e180eac6dc071a79f58f7"}' \
        | "$UNIPLAY" -f marksel \
        | exec "$UNIPLAY" -f 18066364c58e180eac6dc071a79f58f7
fi
