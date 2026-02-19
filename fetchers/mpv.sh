#!/usr/bin/env bash
# Input:
#   * item - file or URL
#   * title - window title (aka --title)
#   * referer - referer HTTP header (aka --http-header-fields)
#   * suburl - URL with subtitles (aka --sub-file)
#   * chapters - array with '{start: time, end: time, text: string}' items (aka --chapters-file)
#   * useragent - user agent HTTP header (aka --user-agent)
# Output: no
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

if <<< "${JSON[@]}" jq -r '.useragent // empty' | read -r UA; then
    ARGS+=("--user-agent=$UA")
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

if <<< "${JSON[@]}" jq -r '.replacepath // empty' | read -r REPLACEPATH; then
    REPLACEPATH="${REPLACEPATH%\?*}"
    dirname "${BASH_SOURCE[0]}" \
        | read -r SCRIPT_DIR
    ARGS+=("--script=$SCRIPT_DIR/replace-path.lua" "--script-opts-append=real-stream-url=${ARGS[0]}")
    echo "mpv: Replace [${ARGS[0]}] by [$REPLACEPATH]" >&2
    ARGS[0]="$REPLACEPATH"
fi

if [[ "${#TEMPS[@]}" -gt 0 ]]; then
    trap "rm ${TEMPS[@]}" INT EXIT
fi

mpv "${ARGS[@]}"
