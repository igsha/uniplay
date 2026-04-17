#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq >/dev/null

"$UNIPLAY" auto \
    | mapfile JSON

while <<< "${JSON[@]}" jq -r '.type, .pipeline' | { read -r TYPE; read -r PIPELINE; }; do
    case "$PIPELINE" in
        manga)
            <<< "${JSON[@]}" "$UNIPLAY" download \
                | "$UNIPLAY" create-pdf \
                | "$UNIPLAY" file-open
            break;;
        film)
            <<< "${JSON[@]}" "$UNIPLAY" mpv
            break;;
        *)
            case "$TYPE" in
                pdf)
                    <<< "${JSON[@]}" "$UNIPLAY" file-open
                    break;;
                video)
                    <<< "${JSON[@]}" "$UNIPLAY" mpv
                    break;;
                text)
                    if <<< "${JSON[@]}" jq -r '.file // empty' | read -r FILE; then
                        echo "pipeline: Show text from $FILE" >&2
                        less "$FILE"
                    else
                        echo "pipeline: Show text" >&2
                        <<< "${JSON[@]}" jq -r .content | less
                    fi
                    break;;
                selectable)
                    <<< "${JSON[@]}" "$UNIPLAY" marksel \
                        | mapfile JSON;;
                *)
                    <<< "${JSON[@]}" "$UNIPLAY" auto \
                        | mapfile JSON;;
            esac;;
    esac
done
