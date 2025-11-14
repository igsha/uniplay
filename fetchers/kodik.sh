#!/usr/bin/env bash
set -e

which jq grep http rg xq fzf tr base64 sed > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .item <<< "${JSON[@]}")

read -r DOMAIN < <(grep -Po ".+//[^/]+" <<< "$URL")

read -r REGISTER < <(mktemp -t uniplayer.kodik.XXX)
trap "rm \"$REGISTER\"" INT EXIT
http --follow --timeout 5 GET "$URL" > "$REGISTER"

read -r TITLE < <(grep -Po "<title>\K.+(?=</title\>)" "$REGISTER")
IFS=$'\t' read -r STITLE URL < <(rg --multiline-dotall -UPo '<div class="serial-series-box".*?</div>' "$REGISTER" \
    | xq -r '.div.select.option[]
| "\(.["@data-title"])\t'$DOMAIN'/ftor?type=seria&id=\(.["@data-id"])&hash=\(.["@data-hash"])"' \
    | fzf)

echo "kodik: Extract $URL" >&2
read -r VAL < <(http GET "$URL" | jq -r '.links["720"][0].src')

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

export TITLE STITLE URL
<<< "${JSON[@]}" jq '.item=env.URL | .title="\(env.TITLE) - \(env.STITLE)"' | "$UNIPLAY" -f mpv
