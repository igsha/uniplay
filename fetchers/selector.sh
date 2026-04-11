#!/usr/bin/env bash
# Input: {list: [{title, [mark], [other fields...]}]}
# Output: json with
#   * selected item,
#   * title - selected item name,
#   * copied selected other fields.
set -e
shopt -s lastpipe

which fzf jq jo > /dev/null

mapfile JSON
<<< "${JSON[@]}" jq -r '.list[0] | has("mark"), (del(.title, .mark) | keys_unsorted[])' \
    | { read -r HASMARK; readarray -t KEYS; }

if [[ "$HASMARK" == "true" ]]; then
    FZFARGS=("--with-nth=1,2" "--accept-nth=2..")
else
    FZFARGS=("--with-nth=1" "--accept-nth=1..")
fi

KEYS=("title" "${KEYS[@]}")
echo "selector: hasmark=$HASMARK keys=[${KEYS[@]}]" >&2
<<< "${JSON[@]}" jq -r '.list[] | [
            .mark // empty,
            .title
        ] + (del(.title, .mark) | to_entries | map(.value)) | @tsv' \
    | fzf -d $'\t' "${FZFARGS[@]}" \
    | read -r RAWVALUES

printf "%s" "$RAWVALUES" \
    | readarray -t -d $'\t' VALUES

echo "selector: values=[${VALUES[@]}]" >&2
{
    <<< "${JSON[@]}" jq 'del(.list, .type)'
    for ((i=0; i < ${#KEYS[@]}; ++i)); do
        jo "${KEYS[$i]}=${VALUES[$i]}"
    done
} | jq -s add
