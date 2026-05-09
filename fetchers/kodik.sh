#!/usr/bin/env bash
# Input: https://kodik.info/season/<id>/<hash>/720p[?translations=false[&episode=<ep>]]
# Output:
#   * ask for translation (if no `translations=false`),
#   * ask for seria (if no `episode=\d+`)
set -e
shopt -s lastpipe

which jq jo http htmlq xq tr base64 sed >/dev/null

jq -r '.url, (.url | split("/")[0:3] | join("/")), .title' \
    | { read -r URL; read -r DOMAIN; read -r TITLE; }

if [[ "$URL" =~ /(video|seria)/([0-9]+)/([a-z0-9]+)/[^/]+\?translations=false ]]; then
    VIDEOTYPE="${BASH_REMATCH[1]}"
    VIDEOID="${BASH_REMATCH[2]}"
    VIDEOHASH="${BASH_REMATCH[3]}"
    echo "kodik: Extract movie $URL" >&2
    jo url="$DOMAIN/ftor?type=$VIDEOTYPE&id=$VIDEOID&hash=$VIDEOHASH" type=url title="$TITLE"
elif [[ "$URL" =~ episode=([0-9]+) ]]; then
    EPISODE="${BASH_REMATCH[1]}"
    echo "kodik: Selected episode $EPISODE of $URL" >&2
    http --follow --timeout 5 GET "$URL" \
        | htmlq '.player_box .get_code_copy' -a data-code \
        | tail -1 \
        | read -r URL

    jo url="$URL?translations=false" title="${TITLE:0:100} - $EPISODE"
elif [[ "$URL" =~ translations=false ]]; then
    http --follow --timeout 5 GET "$URL" \
        | mapfile HTML

    echo "kodik: List series $URL" >&2
    <<< "${HTML[@]}" htmlq title -t \
        | read -r TITLE

    <<< "${HTML[@]}" htmlq .serial-series-box \
        | xq --arg dom "$DOMAIN" --arg title "${TITLE:0:100}" '.div.select.option | if type == "object" then [.] else . end | {
            list: map({
                url: $dom + "/ftor?type=seria&id=" + .["@data-id"] + "&hash=" + .["@data-hash"],
                title: $title + " " + .["@data-title"]
            }) | reverse,
            type: "selectable",
            title: "kodik"}'
elif [[ "$URL" =~ ftor\? ]]; then
    echo "kodik: Extract video $URL" >&2
    http GET "$URL" \
        | jq -r '.links["720"][0].src' \
        | read -r VAL

    CAB="ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ"
    SAB="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
    for ((rot=0; rot<26; ++rot)); do
        rot2=$((rot+1))
        <<< "$VAL" tr "A-Za-z" "${CAB:$rot2:1}-ZA-${CAB:$rot:1}${SAB:$rot2:1}-za-${SAB:$rot:1}" \
            | read -r RES

        if [[ "$RES" =~ ^Ly9 || "$RES" =~ ^aHR0c ]]; then
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

    jo url="$URL" type=video title="$TITLE"
else
    echo "kodik: List dubbers $URL" >&2
    http --follow --timeout 5 GET "$URL" \
        | htmlq '.serial-translations-box, .movie-translations-box' \
        | xq --arg dom "$DOMAIN" '.div.select.option | map({
            url: "\($dom)/\(.["@data-media-type"])/\(.["@data-media-id"])/\(.["@data-media-hash"])/720p?translations=false",
            title: .["#text"]})
            | {list: ., title: "kodik", type: "selectable"}'
fi
