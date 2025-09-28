#!/usr/bin/env bash
set -e

which jq mpv http > /dev/null

ARGS=()
mapfile -t JSON
if ! read -r ARGS[0] < <(jq -r '.url // empty' <<< "${JSON[@]}"); then
    readarray -t ARGS < <(jq -r '.urls[]' <<< "${JSON[@]}")
fi
echo "mpv: Extract ${ARGS[@]}" >&2

if read -r REFERER < <(jq -r '.referer // empty' <<< "${JSON[@]}"); then
    ARGS+=("--http-header-fields=Referer:$REFERER")
fi
if read -r TITLE < <(jq -r '.title // empty' <<< "${JSON[@]}"); then
    ARGS+=("--title=$TITLE")
fi
if read -r SUBURL < <(jq -r '.subsurl // empty' <<< "${JSON[@]}"); then
    read -r REGISTER < <(mktemp -t uniplayer.mpv.XXX)
    trap "rm \"$REGISTER\"" INT EXIT
    echo "Downloading subtitles $SUBURL to $REGISTER"
    http --follow GET "$SUBURL" > "$REGISTER"
    ARGS+=("--sub-file=$REGISTER")
fi

mpv "${ARGS[@]}"
