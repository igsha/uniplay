#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo http > /dev/null

mapfile -t JSON
jq -r .item <<< "${JSON[@]}" | read -r URL
BASEURL="${URL%\?*}"

if [[ "$URL" =~ rshorts ]]; then
    export ITEMURL="https://rutube.ru/shorts/"
elif [[ "$URL" =~ /playlist/user/ ]]; then
    export ITEMURL="https://rutube.ru/plst/"
else
    export ITEMURL="https://rutube.ru/video/"
fi

declare -i PAGENUM=1
if [[ "$URL" =~ \? ]]; then
    URL="${URL}&page=$PAGENUM"
else
    URL="${URL}?page=$PAGENUM"
fi

while [[ "$URL" =~ "$BASEURL" ]]; do
    echo "rutube-list: List $URL" >&2
    http GET "$URL" \
        | jq -r '(.results | map({url: "\(env.ITEMURL)\(.id)", title})) + [select(.next != null) | {url: .next, title: "###next###"}]
                 | {items: map(.url), names: map(.title), result: "urls", title: "rutube"}' \
        | "$UNIPLAY" -f marksel \
        | jq -r '.item' \
        | read -r URL
done

jo result="url" item="$URL"
