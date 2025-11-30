#!/usr/bin/env bash
set -e
shopt -s lastpipe

which http jq jo > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r .item \
    | read -r URL

URLPATTERN="https://api.remanga.org/api/v2/titles/chapters"

if [[ "$URL" =~ [^/]+//[^/]+/manga/([^/?&]+) ]]; then
    REQNAME="${BASH_REMATCH[1]}"
    ORIGURL="${BASH_REMATCH[0]}/"

    URL="https://api.remanga.org/api/v2/titles/$REQNAME/"
    echo "remanga-list: Download list $URL" >&2
    http GET "$URL" \
        | jq -r '(.secondary_name | sub("/"; "-")), .branches[0].id' \
        | { read -r TITLE; read -r  BRANCHID; }

    echo "remanga-list: Chapters for [$TITLE] [$BRANCHID]" >&2

    BASEURL="${URLPATTERN}/?branch_id=$BRANCHID&ordering=-index"
    URL="${BASEURL}&page=1"
else
    echo "remanga-list: Continue list $URL" >&2
    <<< "${JSON[@]}" jq -r '.args | .origurl, .baseurl' \
        | { read -r ORIGURL; read -r BASEURL; }
fi

echo "remanga-list: Download chapters $URL" >&2
export BASEURL ORIGURL URLPATTERN
http --follow GET "$URL" \
    | jq '.next as $next | .results |
          {items: map(env.ORIGURL + "\(.id)") + [select($next != null) | env.BASEURL + "&page=\($next)"],
           names: map("\(.tome)-\(.chapter)-\(.name)") + [select($next != null) | "###next###"],
           title: "remanga",
           call: "remanga-list",
           pattern: env.URLPATTERN,
           args: {baseurl: env.BASEURL, origurl: env.ORIGURL}}'
