#!/usr/bin/env bash
set -e
shopt -s lastpipe

jq -r .url \
    | read -r URL

"$UNIPLAY" self-referer "$URL" \
    | "$UNIPLAY" http \
    | htmlq script -t \
    | mapfile PHTML

<<< "${PHTML[@]}" rg "const fileList = JSON.parse\('(.*)'\);" -or '$1' \
    | mapfile JSON

if [[ "$URL" =~ dubbing_code=([^/&]+) ]]; then
    DUBBER="${BASH_REMATCH[1]}"
    echo "yani: List videos for $DUBBER" >&2
    <<< "${PHTML[@]}" rg "const config = JSON.parse\('(.*)'\);" -or '$1' \
        | jq -r '.mediaMetadata.title' \
        | read -r TITLE

    <<< "${JSON[@]}" jq --arg dub "$DUBBER" --arg title "$TITLE" '.all | to_entries[] | .value | select(.name == $dub) |
        .file | to_entries | map(.value | to_entries | map(.value)) | flatten | {
            list: map({
                url: "https://alloha.yani.tv/bnsi/movies/\(.id)",
                title: "\($title) \(.seasons)-\(.episode)"
            }),
            title: "yani",
            hashkey: "url",
            type: "selectable"}'
elif [[ "$URL" =~ /movies ]]; then
    echo "yani: No ready yet to parse $URL" >&2
    exit 1
else
    echo "yani: List dubbers $URL" >&2
    <<< "${JSON[@]}" jq --arg url "$URL" '.all | to_entries | map(.value) | {
            list: map({
                title: .name,
                url: $url + "&dubbing_code=" + .name}),
            title: "yani",
            hashkey: "url",
            type: "selectable"}'
fi
