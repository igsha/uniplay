#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq sqlite3 http >/dev/null

jq -r '.url, .token, .cookiesdb' \
    | { read -r URL; read -r ACCESS_TOKEN; read -r COOKIES_DB; }

if [[ "$ACCESS_TOKEN" == null ]]; then
    echo "boosty: Extract cookies" >&2
    DBS=(\
        "$XDG_CONFIG_HOME/google-chrome/Default/Cookies" \
        "$XDG_DATA_HOME/qutebrowser/webengine/Cookies" \
    )

    if [[ "$COOKIES_DB" != null ]]; then
        DBS=("$COOKIES_DB" "${DBS[@]}")
    fi

     for COOKIES_DB in "${DBS[@]}"; do
         echo "boosty: Try db $COOKIES_DB" >&2
         if [[ -r "$COOKIES_DB" ]]; then
             if sqlite3 "$COOKIES_DB" "select value from cookies where host_key = '.boosty.to' and name = 'auth';" \
                 | read -r JSON; then
                break
             fi
         fi
     done

    echo "boosty: Parse access token" >&2
    JSON="${JSON//+/ }"
    printf '%b' "${JSON//%/\\x}" \
        | jq -r .accessToken \
        | read -r ACCESS_TOKEN
fi

[[ "$URL" =~ /([^/]+)/posts/([^/]+) ]]
USERNAME="${BASH_REMATCH[1]}"
POST_ID="${BASH_REMATCH[2]}"

URL="https://api.boosty.to/v1/blog/$USERNAME/post/$POST_ID"
echo "boosty: Download videos $URL access=$ACCESS_TOKEN" >&2
http GET "$URL" "Authorization:Bearer $ACCESS_TOKEN" \
    | mapfile JSON

if <<< "${JSON[@]}" jq -e '.data | map(select(.type == "ok_video")) | length == 1' >/dev/null; then
    <<< "${JSON[@]}" jq '.data | map(select(.playerUrls) | .playerUrls | map(select(.url != "") | .key=.type | .value=.url) | from_entries) | first' \
        | tee >(jq -r 'to_entries | map("boosty: Available format [\(.key)] \(.value)") | join("\n")' >&2) \
        | jq -r '.hls // .ultra_hd // .full_hd // .quad_hd' \
        | read -r URL

    <<< "${JSON[@]}" jq -r '.data | map(select(.type == "ok_video") | .duration) | first' \
        | read -r DUR

    <<< "${JSON[@]}" jq --argjson dur "$DUR" '.data | map(
            select(.type == "text" or .type == "link") |
            if .modificator == "BLOCK_END" then "" else (.content | fromjson[0] | trim) end) |
            reverse as $arr | [
                foreach range($arr | length) as $i (
                    {prev: $dur, item: null};
                    if $arr[$i] | test("(\\d+:)?\\d+:\\d+") then
                        .prev as $prev | ($arr[$i] | capture("(?:(?<h>\\d+):)?(?<m>\\d+):(?<s>\\d+)") |
                            with_entries(.value |= (. // 0 | tonumber)) | .h * 3600 + .m * 60 + .s) as $time |
                        {prev: $time, item: {start: $time * 1000, end: $prev * 1000, text: $arr[$i-1]}}
                    else
                        {prev: .prev, item: null}
                    end;
                    .item
                ) | select(. != null)
            ] | reverse' \
        | mapfile CHAPJSON

    if <<< "${CHAPJSON[@]}" jq -e '. | length > 1' >/dev/null; then
        <<< "${CHAPJSON[@]}" jq --arg url "$URL" '{chapters: ., url: $url, type: "video"}'
    else
        <<< "$URL" jq -R '{url: ., type: "video"}'
    fi
else
    echo "boosty: Several urls are not implemented ${JSON[@]}" >&2
    exit 1
fi
