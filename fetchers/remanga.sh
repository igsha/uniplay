#!/usr/bin/env bash
set -e
shopt -s lastpipe

jq -r .url \
    | read -r URL

if [[ "$URL" =~ [^/]+//[^/]+/manga/([^/]+)/([0-9]+) ]]; then
    URL="https://api.remanga.org/api/v2/titles/chapters/${BASH_REMATCH[2]}/"
    TITLE="${BASH_REMATCH[1]}"

    echo "remanga: Download chapter $URL" >&2
    http GET "$URL" \
        | jq --arg title "$TITLE" '.pages | flatten | {
            list: map({url: .link}),
            title: $title,
            type: "images",
            pipeline: "manga",
            parallel: 4,
            referer: "https://remanga.org/"}'
else
    if [[ "$URL" =~ [^/]+//[^/]+/manga/([^/?&]+) ]]; then
        REQNAME="${BASH_REMATCH[1]}"
        ORIGURL="${BASH_REMATCH[0]}/"

        URL="https://api.remanga.org/api/v2/titles/$REQNAME/"
        echo "remanga: List chapters $URL" >&2
        http GET "$URL" \
            | jq -r '(.secondary_name | sub("/"; "-")), .branches[0].id' \
            | { read -r TITLE; read -r  BRANCHID; }

        echo "remanga: Chapters for [$TITLE] [$BRANCHID]" >&2

        BASEURL="https://api.remanga.org/api/v2/titles/chapters/?branch_id=$BRANCHID&ordering=-index"
        URL="${BASEURL}&page=1"
    elif [[ "$URL" =~ page= ]]; then
        echo "remanga: Continue list $URL" >&2
    else
        echo "remanga: Wrong url $URL" >&2
        exit 1
    fi

    echo "remanga: Download chapters $URL" >&2
    http --follow GET "$URL" \
        | jq --arg url "$ORIGURL" --arg base "$BASEURL" '.next as $next | .results | {
            list: map({
                url: "\($url)\(.id)",
                title: "\(.tome)-\(.chapter)-\(.name)"})
                + [select($next != null) | {
                    url: "\($base)&page=\($next)",
                    title: "###next###"}],
            title: "remanga",
            hashkey: "url",
            type: "selectable"}'
fi
