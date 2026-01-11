#!/usr/bin/env bash
# Input: https://kodik.info/season/<id>/<hash>/720p[?translations=false[&episode=<ep>]]
# Output:
#   * ask for translation (if no `translations=false`),
#   * ask for seria (if no `episode=\d+`)
set -e
shopt -s lastpipe

which jq jo http htmlq xq tr base64 sed > /dev/null

jq -r '.item, (.item | split("/")[0:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

if [[ "$URL" =~ translations=false ]]; then
    EPISODE="-1"
    if [[ "$URL" =~ episode=([0-9]+) ]]; then
        EPISODE="${BASH_REMATCH[1]}"
        echo "kodik: Selected episode $EPISODE" >&2
    fi

    echo "kodik: Download html $URL" >&2
    http --follow --timeout 5 GET "$URL" \
        | mapfile HTML

    <<< "${HTML[@]}" htmlq title -t \
        | read -r TITLE

    <<< "${HTML[@]}" htmlq .serial-series-box \
        | xq --arg dom "$DOMAIN" '.div.select.option | if type == "object" then [.] else . end | {
            items: map({
                item: $dom + "/ftor?type=seria&id=" + .["@data-id"] + "&hash=" + .["@data-hash"],
                name: .["@data-title"]
            }) | reverse,
            title: "kodik"}' \
        | {
            if [[ "$EPISODE" -eq -1 ]]; then
                echo "kodik: List series" >&2
                "$UNIPLAY" -f marksel
            else
                # negative episode due to reverse
                jq --argjson ep "$EPISODE" '.items[-$ep] | {item, title: .name}'
            fi
        } \
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

    # Fix wrong resolution in url
    if [[ ! "$URL" =~ 720\.mp4 ]]; then
        URL="${URL/???.mp4/720.mp4}"
    fi

    jo result=url item="$URL" title="$TITLE - $STITLE" \
        | "$UNIPLAY" -f mpv
else
    echo "kodik: List dubbers $URL" >&2
    http --follow --timeout 5 GET "$URL" \
        | htmlq .serial-translations-box \
        | xq --arg dom "$DOMAIN" '.div.select.option | map({
            item: "\($dom)/\(.["@data-media-type"])/\(.["@data-media-id"])/\(.["@data-media-hash"])/720p?translations=false",
            name: .["#text"]})
            | {items: ., title: "kodik"}' \
        | "$UNIPLAY" -f selector \
        | exec "$UNIPLAY" -f kodik
fi
