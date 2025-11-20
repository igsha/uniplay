#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq mpv http > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.item // .items[]' \
    | readarray -t ARGS

[[ "${#ARGS[@]}" -gt 0 ]]
echo "mpv: Extract ${ARGS[@]}" >&2

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    ARGS+=("--http-header-fields=Referer:$REFERER")
fi

if <<< "${JSON[@]}" jq -r '.title // empty' | read -r TITLE; then
    ARGS+=("--title=$TITLE")
fi

TEMPS=()
if <<< "${JSON[@]}" jq -r '.subsurl // empty'| read -r SUBURL; then
    mktemp -t uniplay.mpv.XXX \
        | read -r REGISTER
    TEMPS+=("$REGISTER")

    echo "mpv: Download subtitles $SUBURL to $REGISTER" >&2
    http --follow GET "$SUBURL" > "$REGISTER"
    ARGS+=("--sub-file=$REGISTER")
fi

if <<< "${JSON[@]}" jq -r '(.chapters // [])[] | "[CHAPTER]\nTIMEBASE=1/1000\nSTART=\(.start)\nEND=\(.end)\ntitle=\(.text)\n"' \
    | readarray CHAPTERS && [[ "${#CHAPTERS[@]}" -gt 0 ]]; then
    mktemp -t uniplay.mpv.XXX \
        | read -r CHAPTERSFILE
    TEMPS+=("$CHAPTERSFILE")

    echo "mpv: Store chapters in $CHAPTERSFILE" >&2
    echo ";FFMETADATA1" > "$CHAPTERSFILE"
    printf "%s" "${CHAPTERS[@]}" >> "$CHAPTERSFILE"

    ARGS+=("--chapters-file=$CHAPTERSFILE")
fi

if [[ "${#TEMPS[@]}" -gt 0 ]]; then
    trap "rm ${TEMPS[@]}" INT EXIT
fi

mpv "${ARGS[@]}"
