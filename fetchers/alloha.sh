#!/usr/bin/env bash
set -eo pipefail
shopt -s lastpipe

which jq htmlq rg >/dev/null

jq -r '.url, (.url | split("/")[:3] | join("/"))' \
    | { read -r URL; read -r DOMAIN; }

declare -A DOMAINMAP=(\
    ["https://absciss.thealloha.club"]="https://yummyanime.tv" \
)
GUARDHEX=(\
    a5 7c ef 6f 20 c6 2d 8c 81 e9 59 30 b1 66 43 bf \
    78 8c 29 9b 6c 5c dc e9 cd 1c b1 65 47 2c 28 75 \
    f1 b1 27 9a 61 a9 1b a3 78 70 f6 60 45 45 ce 55 \
    41 3a 6a 01 7e 81 5b c6 83 12 ac 8b 68 76 1c 5d \
    24 22 57 a2 87 61 35 53 2b a3 18 46 98 4d 03 2e \
    6c 06 3b 6b 7a fa a4 0f 32 a6 2e a3 5d 7c c6 46 \
    11 4f 4d 10 b8 e6 b4 a7 d9 cb 74 4d 1b 30 9d ef \
    ae ec 36 1d 66 5c 48 f8 b4 27 2f aa 77 47 b7 39 \
    b0 01 b6 4d 92 19 b8 82 10 c4 6a ca 1d a2 d3 01 \
    7b 0c a9 35 0e 7a ba 8b 49 01 01 97 d7 57 2c 7d \
    e4 5f 04 03 e4 f0 37 14 59 69 24 ab 3c 5c 6b cb \
    db 9c 4c 35 da f5 05 6c 1c d3 ea 1c fc 64 1d c5 \
    dd dc d4 85 45 e8 2f 67 2b d5 63 35 6d 74 00 ad \
    10 92 d4 c5 0d 33 3d d7 e5 60 cc 31 0a 19 2b 18 \
    f6 00 c4 d1 aa 9e d0 41 7e 1d 0c 1f 41 ed 5c c4 \
    65 39 b2 15 42 e1 9b 50 1c 1c 73 24 a0 cb d2 56 \
    f2 98 a0 1a 00 28 bc 9c 60 08 0c 1d e0 f8 10 22 \
    5c 18 40 06 a6 79 09 86 b5 79 ef 34 3b \
)

PAGEDOMAIN="${DOMAINMAP[$DOMAIN]:-$DOMAIN}"
http --check-status GET "$URL" referer:"$PAGEDOMAIN" \
    | mapfile HTML

<<< "${HTML[@]}" htmlq script -t \
    | mapfile PHTML

<<< "${PHTML[@]}" rg "const fileList = JSON.parse\('(.*)'\);" -or '$1' \
    | jq '.all | to_entries | map(.value | (.file? // .) | to_entries | map(.value | to_entries | map(.value))) | flatten' \
    | mapfile JSON

if [[ "$URL" =~ translation=([^/&]+) ]]; then
    DUBBER="${BASH_REMATCH[1]}"
    if [[ "$URL" =~ season=([0-9]+) ]]; then
        SEASON="${BASH_REMATCH[1]}"
        if [[ "$URL" =~ episode=([0-9]+) ]]; then
            EPISODE="${BASH_REMATCH[1]}"
            echo "alloha: Select episode $SEASON-$EPISODE [$DUBBER] in $URL" >&2

            <<< "${JSON[@]}" jq --argjson dub "$DUBBER" --argjson s "$SEASON" --argjson ep "$EPISODE" \
                    'map(select(.id_translation == $dub and .seasons == $s and .episode == $ep)) | first | .id' \
                | read -r ID

            <<< "${HTML[@]}" htmlq 'meta[name="viewporti"]' -a content \
                | PATH+=":$UNIPLAYPATH" borth.sh \
                | read -r BORTH

            [[ "$URL" =~ token=([^&]+) ]]
            TOKEN="${BASH_REMATCH[1]}"

            <<< "$BORTH" sha256sum \
                | cut -c -64 \
                | read -r SALT

            echo "alloha: Donwload m3u8 salt=$SALT" >&2
            echo "alloha: Donwload m3u8 borth=$BORTH" >&2
            http -f --ignore-stdin POST "$DOMAIN/bnsi/movies/$ID" \
                    "origin:$DOMAIN" "referer:$URL" "borth:$SALT|$BORTH" \
                    "token=$TOKEN" av1=true audio= subtitle= \
                | mapfile JSON

            <<< "${PHTML[@]}" rg "const config = JSON.parse\('(.*)'\);" -or '$1' \
                | jq -r '.mediaMetadata.title' \
                | read -r TITLE

            <<< "${JSON[@]}" jq '.hlsSource[0] | .quality | to_entries | map(.key as $key | .value | split(" or ")[] | {key: $key, value: .})' \
                | tee >(jq -r '.[] | "alloha: [\(.key)] [\(.value)]"' >&2) \
                | jq -r '.[0].value' \
                | read -r HLSURL

            echo "alloha: Extract inner hls from $HLSURL" >&2
            http GET "$HLSURL" "origin:$DOMAIN" \
                | grep -v '#' \
                | mapfile -t HLSPART

            HLSURL="${HLSURL/master.m3u8/${HLSPART[0]}}"

            printf "\\\\\\\x%s" "${GUARDHEX[@]}" \
                | xargs printf "%b" \
                | base64 -w0 \
                | mapfile GUARD

            echo "alloha: Guard ${GUARD[@]}" >&2
            jo "headers[origin]=$DOMAIN" "headers[accepts-controls]=$SALT" "headers[authorizations]=Bearer ${GUARD[@]}" url="$HLSURL" type=video title="$TITLE - $SEASON-$EPISODE" \
                | "$UNIPLAY" download-m3u8
        else
            echo "alloha: List episode season=$SEASON dubber=$DUBBER for $URL" >&2
            <<< "${JSON[@]}" jq --argjson dub "$DUBBER" --argjson season "$SEASON" --arg url "$URL" 'map(select(.id_translation == $dub and .seasons == $season) | {
                    url: "\($url)&episode=\(.episode)",
                    title: "Episode \(.episode)"
                }) | {
                    list: .,
                    title: "alloha",
                    hashkey: "url",
                    type: "selectable"
                }'
        fi
    else
        echo "alloha: List seasons for $DUBBER in $URL" >&2
        <<< "${JSON[@]}" jq --argjson dub "$DUBBER" --arg url "$URL" 'map(select(.id_translation == $dub) | {
                url: "\($url)&season=\(.seasons)",
                title: "Season \(.seasons)"
            }) | {
                list: (. | unique_by(.url)),
                title: "alloha",
                hashkey: "url",
                type: "selectable"
            }'
    fi
elif [[ "$URL" =~ /movies ]]; then
    echo "alloha: The inner link without salt and borth $URL" >&2
    exit 1
else
    echo "alloha: List dubbers $URL" >&2
    <<< "${JSON[@]}" jq --arg url "$URL" 'unique_by(.id_translation) | map({
                title: .translation,
                url: "\($url)&translation=\(.id_translation)"
            }) | {
                list: .,
                title: "alloha",
                hashkey: "url",
                type: "selectable"
            }'
fi
