#!/usr/bin/env bash
set -e

which grep http rg xq fzf tr base64 sed jo > /dev/null

if [[ ! "$2" =~ kodik ]]; then
    jo result=notmine
    exit 0
fi

read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$2")
read -r TITLE < <(grep -Po "<title>\K.+(?=</title\>)" "$1")
IFS=$'\t' read -r STITLE URL < <(rg --multiline-dotall -UPo '<div class="serial-series-box".*?</div>' "$1" \
    | xq -r '.div.select.option[]
| "\(.["@data-title"])\t'$DOMAIN'/ftor?type=seria&id=\(.["@data-id"])&hash=\(.["@data-hash"])"' \
    | fzf)

read -r VAL < <(http GET "$URL" \
    | jq -r '.links["720"][0].src')

CAB="ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ"
SAB="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
for ((rot=0; rot<25; ++rot)); do
    rot2=$((rot+1))
    read -r RES < <(echo "$VAL" \
        | tr "A-Za-z" "${CAB:$rot2:1}-ZA-${CAB:$rot:1}${SAB:$rot2:1}-za-${SAB:$rot:1}")
    if [[ "$RES" =~ ^Ly9 ]]; then
        URL="$(echo "$RES" | base64 -d | sed 's;^//;https://;')"
        break
    fi
done

echo "Play URL: $URL" >&2
jo result=video "title=$TITLE - $STITLE"  "url=$URL"
