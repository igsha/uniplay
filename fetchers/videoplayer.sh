#!/usr/bin/env bash
set -e

which grep jq http xmllint jo > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")
if read -r REFERER < <(jq -r '.referer // empty' <<< "${JSON[@]}"); then
    REFERER="referer:$REFERER"
fi

read -r REGISTER < <(mktemp -t uniplayer.videoplayer.XXX)
trap "rm \"$REGISTER\"" INT EXIT
http --follow --timeout 5 GET "$URL" $REFERER > "$REGISTER"

readarray -t URLS < <(xmllint "$REGISTER" --html -xpath '//video[@id="videoplayer"]/source//@src' 2>/dev/null \
    | grep -Po 'src="\K[^"]+')

for URL in "${URLS[@]}"; do
    echo "videoplayer: Extract $URL" >&2
done

CMDPART=""
if read -r SUBURL < <(grep -Po "subtitles: \K\[[^\]]+\]" "$REGISTER" | jq -r '.[0] | .src'); then
    echo "videoplayer: Extract subs $SUBURL" >&2
    export SUBURL
    CMDPART='| .subsurl=env.SUBURL'
fi

read -r URLS < <(jo -a "${URLS[@]}")
jq --argjson urls "$URLS" '.result="urls" | del(.url) | .urls=$urls'"$CMDPART" <<< "${JSON[@]}"
