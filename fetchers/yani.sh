#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq htmlq rg >/dev/null

jq -r .url \
    | read -r URL

"$UNIPLAY" self-referer "$URL" \
    | "$UNIPLAY" http \
    | htmlq script -t \
    | mapfile PHTML

<<< "${PHTML[@]}" rg "const fileList = JSON.parse\('(.*)'\);" -or '$1' \
    | mapfile JSON

if [[ "$URL" =~ translation=([^/&]+) ]]; then
    DUBBER="${BASH_REMATCH[1]}"
    <<< "${PHTML[@]}" rg "const config = JSON.parse\('(.*)'\);" -or '$1' \
        | jq -r '.mediaMetadata.title' \
        | read -r TITLE

    if [[ "$URL" =~ season=([0-9]+).*episode=([0-9]+) ]]; then
        SEASON="${BASH_REMATCH[1]}"
        EPISODE="${BASH_REMATCH[2]}"
        echo "yani: Select episode $SEASON-$EPISODE [$DUBBER] in $URL" >&2

        <<< "${JSON[@]}" jq --argjson dub "$DUBBER" --arg title "$TITLE" --argjson s "$SEASON" --argjson ep "$EPISODE" \
            '.all | [.[].file.[].[]] | map(select(.id_translation == $dub and .seasons == $s and .episode == $ep)) | first | {
                url: "https://alloha.yani.tv/bnsi/movies/\(.id)",
                title: "\($title) \($s)-\($ep)"}'
    else
        echo "yani: List videos for $DUBBER in $URL" >&2

        <<< "${JSON[@]}" jq --argjson dub "$DUBBER" --arg title "$TITLE" '.all | [.[].file.[].[]] | {
            list: map(select(.id_translation == $dub) | {
                url: "https://alloha.yani.tv/bnsi/movies/\(.id)",
                title: "\($title) \(.seasons)-\(.episode)"
            }),
            title: "yani",
            hashkey: "url",
            type: "selectable"}'
    fi
elif [[ "$URL" =~ /movies ]]; then
    echo "yani: No ready yet to parse $URL" >&2
    exit 1
else
    echo "yani: List dubbers $URL" >&2
    <<< "${JSON[@]}" jq --arg url "$URL" '.all | to_entries | map(.value + {t: .key[1:]}) | {
            list: map({
                title: .name,
                url: $url + "&translation=" + .t}),
            title: "yani",
            hashkey: "url",
            type: "selectable"}'
fi
