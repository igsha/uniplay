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
<<< "${JSON[@]}" jq -r '.url // .urls[]' \
    | readarray -t ARGS

[[ "${#ARGS[@]}" -gt 0 ]]
echo "mpv: Extract ${ARGS[@]}" >&2

if <<< "${JSON[@]}" jq -r '.referer // empty' | read -r REFERER; then
    echo "mpv: Use referer=$REFERER" >&2
    ARGS+=("--http-header-fields=Referer:$REFERER")
fi

if <<< "${JSON[@]}" jq -r '.title // empty' | read -r TITLE; then
    echo "mpv: Use title=$TITLE" >&2
    ARGS+=("--title=$TITLE")
fi

if <<< "${JSON[@]}" jq -r '.useragent // empty' | read -r UA; then
    echo "mpv: Use user-agent=$UA" >&2
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

if <<< "${JSON[@]}" jq -r '.proxy // empty' | read -r PROXY; then
    if [[ "${PROXY:0:5}" == socks ]]; then
        which gost pkill >/dev/null
        USE_GOST=1
        coproc GOST { gost -L http://:8080 -F "$PROXY"; }
        sleep 0.5

        echo "mpv: Replace $PROXY by gost pid=$GOST_PID" >&2
        PROXY="http://localhost:8080"
    fi

    echo "mpv: Use proxy=$PROXY" >&2
    ARGS+=("--http-proxy=$PROXY" "--demuxer-max-bytes=512MiB" "--demuxer-readahead-secs=20")
fi

cleanup() {
    if [[ "${#TEMPS[@]}" -gt 0 ]]; then
        echo "mpv: cleanup ${TEMPS[@]}" >&2
        rm "${TEMPS[@]}"
    fi
    if [[ "$USE_GOST" -eq 1 && -n "$GOST_PID" ]]; then
        echo "mpv: cleanup gost $GOST_PID" >&2
        pkill -P "${GOST_PID}"
    fi
}

trap cleanup EXIT

mpv "${ARGS[@]}"
