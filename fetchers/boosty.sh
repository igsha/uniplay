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
echo "boosty: Download videos $URL" >&2
http GET "$URL" "Authorization:Bearer $ACCESS_TOKEN" \
    | jq '.data | map(.playerUrls | map(select(.url != "") | .key=.type | .value=.url) | from_entries)' \
    | mapfile JSON

if <<< "${JSON[@]}" jq -e 'length == 1' >/dev/null; then
    <<< "${JSON[@]}" jq -r '.[0] | to_entries | map("boosty: Available format [\(.key)] \(.value)") | join("\n")' >&2
    <<< "${JSON[@]}" jq -r '.[0] | .hls // .ultra_hd // .full_hd // .quad_hd' \
        | read -r URL

    jo url="$URL" type="video"
else
    echo "boosty: Several urls are not implemented ${JSON[@]}" >&2
    exit 1
fi
