#!/usr/bin/env bash
set -e

which jq http htmlq > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")

read -r REGISTER < <(mktemp -t uniplayer.aaf2.XXX)
trap "rm \"$REGISTER\"" INT EXIT
http --follow --timeout 5 GET "$URL" > "$REGISTER"

mapfile -t URLS < <(htmlq 'video > source' -a src < "$REGISTER")
[[ "${#URLS[@]}" -ne 0 ]] || { echo "ERROR: Empty urls"; exit 1; }

read -r TITLE < <(htmlq 'head > title' -t < "$REGISTER")

for URL in "${URSL[@]}"; do
    echo "aaf21f422339a9526f2e3099a5937249: Extract $URL" >&2
done

export URL="${URLS[0]}" TITLE
jq '.url=env.URL | .title=env.TITLE' <<< "${JSON[@]}" | "$UNI" mpv
