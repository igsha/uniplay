#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http grep sed base64 tee > /dev/null

jq -r '.item, (.item | split("/")[0:3] | join("/")), (.useragent // empty)' \
    | {
        read -r URL
        read -r DOMAIN
        if ! read -r UA; then
            "$UNIPLAY" -f random-user-agent "$URL" \
                | jq -r .useragent \
                | read -r UA
        fi
    }

echo "obrut: Extract $URL with ref=$DOMAIN, ua=$UA" >&2
http GET "$URL" "referer:$DOMAIN" "user-agent:$UA" \
    | grep -oP 'new Player\("\K[^"]+' \
    | sed 's;//[A-Za-z0-9]\+=;;g' \
    | read ENCRYPTED

<<< "ey${ENCRYPTED#*ey}" base64 -d \
    | mapfile JSON

if <<< "${JSON[@]}" jq -e '.file[0] | has("folder")' > /dev/null; then
    echo "obrut: Parse serial" >&2
    <<< "${JSON[@]}" jq '.file | map(
            .title as $season | .folder | map(
                .title as $episode | .folder | map(
                    . + {season: $season, episode: $episode})))
            | flatten | map(pick(.title,.t1,.file,.season,.episode))' \
        | mapfile JSON
else
    echo "obrut: Parse movie" >&2
    <<< "${JSON[@]}" jq '.file | map(pick(.title,.t1,.file) + {season: 0, episode: 0})' \
        | mapfile JSON
fi

if [[ "$URL" =~ dubbing=([^?&]+) ]]; then
    DUB="${BASH_REMATCH[1]}"
    echo "obrut: List series for [$DUB]" >&2
    <<< "${JSON[@]}" jq --arg dub "${BASH_REMATCH[1]}" 'map(select(.title == $dub))
            | {items: map({item: .file, name: ("\($dub) \(.season)-\(.episode)" as $sup | .t1 | select(. != "") // $sup)}), title: "obrut"}' \
        | "$UNIPLAY" -f marksel \
        | jq '.item |= (. | split(",") | map(
                match("\\[(\\w+)\\]([^ ]+)")
                | {key: .captures[0].string, value: .captures[1].string}
            ) | sort_by(.key | (match("(\\d+)p") | .captures[0].string | tonumber) // 0)
            | reverse)' \
        | tee >(jq -r '.item[] | "obrut: [\(.key)] \(.value)"' >&2) \
        | jq --arg dom "$DOMAIN" --arg ua "$UA" --arg url "$URL" '.item |= .[0].value | .referer=$dom | .useragent=$ua | .replacepath=$url' \
        | exec "$UNIPLAY" -f mpv
else
    echo "obrut: List dubbers" >&2
    <<< "${JSON[@]}" jq --arg url "$URL" 'group_by(.title) | map(.[0].title as $name | {
                name: $name,
                count: length,
                item: "\($url)?dubbing=\($name)"})
            | {items: ., title: "obrut"}' \
        | "$UNIPLAY" -f selector \
        | exec "$UNIPLAY" -f obrut
fi
