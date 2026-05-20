#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq htmlq rg >/dev/null

jq -r .url \
    | read -r URL

"$UNIPLAY" self-referer "$URL" \
    | "$UNIPLAY" http \
    | mapfile HTML

<<< "${HTML[@]}" htmlq script -t \
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

        <<< "${JSON[@]}" jq --argjson dub "$DUBBER" --argjson s "$SEASON" --argjson ep "$EPISODE" \
                '.all | [.[].file.[].[]] | map(select(.id_translation == $dub and .seasons == $s and .episode == $ep)) | first | .id' \
            | read -r ID

        <<< "${HTML[@]}" htmlq 'meta[name="viewporti"]' -a content \
            | PATH+=":$UNIPLAYPATH" borth.sh \
            | read -r BORTH

        [[ "$URL" =~ token=([^&]+) ]]
        TOKEN="${BASH_REMATCH[1]}"

        <<< "$BORTH" sha256sum \
            | cut -c -64 \
            | read -r SALT

        http -f --ignore-stdin POST "https://alloha.yani.tv/bnsi/movies/$ID" \
                origin:https://alloha.yani.tv referer:"$URL" borth:"$SALT|$BORTH" \
                token="$TOKEN" av1=true audio= subtitle= \
            | mapfile JSON

        <<< "${JSON[@]}" jq '.hlsSource | map(select(.default)) | first | .quality | to_entries | map(.key as $key | .value | split(" or ")[] | {key: $key, value: .})' \
            | tee >(jq -r '.[] | "yani: [\(.key)] [\(.value)]"' >&2) \
            | jq -r '.[0].value' \
            | read -r HLSURL

        echo "yani: Extract hls url $HLSURL" >&2
        GUARD="pXzvbyDGLYyB6VkwsWZDv3iMKZtsXNzpzRyxZUcsKHXxsSeaYakbo3hw9mBFRc5VQTpqAX6BW8aDEqyLaHYcXSQiV6KHYTVTK6MYRphNAy5sBjtrevqkDzKmLqNdfMZGEU9NELjmtKfZy3RNGzCd767sNh1mXEj4tCcvqndHtzmwAbZNkhm4ghDEasodotMBewypNQ56uotJAQGX11csfeRfBAPk8DcUWWkkqzxca8vbnEw12vUFbBzT6hz8ZB3F3dzUhUXoL2cr1WM1bXQArRCS1MUNMz3X5WDMMQoZKxj2AMTRqp7QQX4dDB9B7VzEZTmyFULhm1AcHHMkoMvSVvKYoBoAKLycYAgMHeD4ECJcGEAGpnkJhrV57zQ7"
        jo url="$HLSURL" origin=https://alloha.yani.tv type=video title="$TITLE - $SEASON-$EPISODE"
    else
        echo "yani: List videos for $DUBBER in $URL" >&2

        <<< "${JSON[@]}" jq --argjson dub "$DUBBER" --arg title "$TITLE" --arg url "$URL" '.all | [.[].file.[].[]] | {
            list: map(select(.id_translation == $dub) | {
                url: "\($url)&season=\(.seasons)&episode=\(.episode)",
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
