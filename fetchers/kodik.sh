#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo http htmlq xq tr base64 sed > /dev/null

jq -r .item \
    | read -r URL

DOMAIN="${URL%${URL#*//*/}}"

http --follow --timeout 5 GET "$URL" \
    | mapfile HTML

<<< "${HTML[@]}" htmlq title -t \
    | read -r TITLE

export DOMAIN
<<< "${HTML[@]}" htmlq .serial-series-box \
    | xq '.div.select.option | {
        items: map(env.DOMAIN + "ftor?type=seria&id=" + .["@data-id"] + "&hash=" + .["@data-hash"]),
        names: map(.["@data-title"]),
        title: "kodik"}' \
    | "$UNIPLAY" -f marksel \
    | jq -r '.item,.title' \
    | { read -r URL; read -r STITLE; }

echo "kodik: Extract $URL" >&2
http GET "$URL" \
    | jq -r '.links["720"][0].src' \
    | read -r VAL

CAB="ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ"
SAB="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
for ((rot=0; rot<25; ++rot)); do
    rot2=$((rot+1))
    <<< "$VAL" tr "A-Za-z" "${CAB:$rot2:1}-ZA-${CAB:$rot:1}${SAB:$rot2:1}-za-${SAB:$rot:1}" \
        | read -r RES

    if [[ "$RES" =~ ^Ly9 ]]; then
        <<< "$RES" base64 -d \
            | { sed -e 's;^//;https://;'; echo; } \
            | read -r URL

        echo "kodik: Extract $URL" >&2
        break
    fi
done

jo result=url item="$URL" title="$TITLE - $STITLE" \
    | "$UNIPLAY" -f mpv
