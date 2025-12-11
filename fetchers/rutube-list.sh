#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo http > /dev/null

mapfile -t JSON
jq -r .item <<< "${JSON[@]}" | read -r URL
BASEURL="${URL%\?*}"

if [[ "$URL" =~ rshorts ]]; then
    ITEMURL="https://rutube.ru/shorts/"
elif [[ "$URL" =~ /playlist/user/ ]]; then
    ITEMURL="https://rutube.ru/plst/"
else
    ITEMURL="https://rutube.ru/video/"
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
        | jq -r --arg itemurl "$ITEMURL" '.next as $next | .results |
            {items: map({item: $itemurl + "\(.id)", name: .title})
                + [select($next != null) | {item: $next, name: "###next###"}],
             title: "rutube"}' \
        | "$UNIPLAY" -f marksel \
        | jq -r '.item' \
        | read -r URL
done

jo result=url item="$URL"
