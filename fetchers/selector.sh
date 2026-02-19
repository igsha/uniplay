#!/usr/bin/env bash
# Input: {items: [{item, name, [mark], [other fields...]}]}
# Output: json with
#   * selected item,
#   * title - selected item name,
#   * copied selected other fields.
set -e
shopt -s lastpipe

which fzf jq jo > /dev/null

mapfile ORIGJSON
<<< "${ORIGJSON[@]}" jq --raw-output0 '.items[]' \
    | mapfile -d '' -t JSONS

<<< "${JSONS[0]}" jq -r 'has("mark"), (del(.item, .name, .mark) | select(. | length > 0) | keys_unsorted | .[])' \
    | { read -r HASMARK; readarray -t RESTKEYS; }

if [[ "$HASMARK" == "true" ]]; then
    FZFARGS=("--with-nth=1,2" "--accept-nth=2..")
else
    FZFARGS=("--with-nth=1" "--accept-nth=1..")
fi

echo "selector: hasmark=$HASMARK restkeys=[${RESTKEYS[@]}]" >&2
for JSON in "${JSONS[@]}"; do
    <<< "$JSON" jq -r '.item, .name' \
        | { read -r ITEM; read -r NAME; }

    if [[ "$HASMARK" == "true" ]]; then
        <<< "$JSON" jq -j '"\(.mark)\t"'
    fi

    printf '%s\t%s' "$NAME" "$ITEM"

    if [[ "${#RESTKEYS[@]}" -ne 0 ]]; then
        <<< "$JSON" jq -r 'del(.item, .name, .mark) | to_entries | map(.value) | @tsv | "\t" + .'
    else
        echo
    fi
done \
    | fzf -1 -d $'\t' "${FZFARGS[@]}" \
    | IFS=$'\t' read -r NAME ITEM REST

if <<< "${ORIGJSON[@]}" jq -r '.pattern // empty' | read -r PATTERN && [[ "$ITEM" =~ "$PATTERN" ]]; then
    <<< "${ORIGJSON[@]}" jq -r .call \
        | read -r CALL

    echo "selector: Callback [$CALL], pattern [$PATTERN]" >&2
    <<< "${ORIGJSON[@]}" jq --arg name "$NAME" --arg item "$ITEM" 'del(.items) | .title=$name | .item=$item' \
        | "$UNIPLAY" -f "$CALL" \
        | exec "$UNIPLAY" -f selector
else
    {
        if [[ "${#RESTKEYS[@]}" -ne 0 ]]; then
            echo "selector: rest=[$REST]" >&2
            printf "%s" "$REST" \
                | mapfile -d $'\t' -t RESTVALUES

            for ((i=0; i < ${#RESTKEYS[@]}; ++i)); do
                jo "${RESTKEYS[$i]}=${RESTVALUES[$i]}"
            done
        fi

        jo item="$ITEM" title="$NAME"
    } \
        | jq -s add
fi
