#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http htmlq > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .item <<< "${JSON[@]}")
if [[ "$URL" =~ ([^:]+)://(.+) && "${BASH_REMATCH[1]:0:4}" != http ]]; then
    URL="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    echo "aaf21f422339a9526f2e3099a5937249: Convert to $URL" >&2
fi

read -r REGISTER < <(mktemp -t uniplayer.aaf2.XXX)
trap "rm \"$REGISTER\"" INT EXIT
http --follow --timeout 5 GET "$URL" > "$REGISTER"

while [[ "$URL" =~ /models/ ]]; do
    < "$REGISTER" \
        htmlq '.list-videos a.thumb_title' \
        | rg 'href="([^"]+)".*title="([^"]+)"' -or $'$1\t$2' \
        | readarray -t LIST

    if < "$REGISTER" \
        htmlq '#list_videos_common_videos_list_pagination li.next > a' -a href \
        | read -r NEXTURL; then
        awk -F/ '{printf "%s//%s\n", $1, $3}' <<< "$URL" \
            | read -r DOMAIN
        LIST+=("$DOMAIN$NEXTURL"$'\t'"next")
    fi

    printf "%s\n" "${LIST[@]}" \
        | fzf -d $'\t' --with-nth=2 --accept-nth=1 \
        | read -r URL

    http --follow --timeout 5 GET "$URL" > "$REGISTER"
done

mapfile -t URLS < <(htmlq 'video > source' -a src < "$REGISTER")
[[ "${#URLS[@]}" -ne 0 ]] || { echo "ERROR: Empty urls"; exit 1; }

read -r TITLE < <(htmlq 'head > title' -t < "$REGISTER")

for URL in "${URLS[@]}"; do
    echo "aaf21f422339a9526f2e3099a5937249: Extract $URL" >&2
done

export URL="${URLS[0]}" TITLE
<<< "${JSON[@]}" jq '.item=env.URL | .title=env.TITLE' | "$UNIPLAY" -f mpv
