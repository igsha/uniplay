#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq sqlite3 md5sum cut > /dev/null

mapfile JSON
if <<< "${JSON[@]}" jq -r '.call // empty' | read -r CALL && [[ "$CALL" == marksel ]]; then
    # we were called again
    <<< "${JSON[@]}" jq -r .args.call \
        | read -r CALL

    echo "marksel: Callback [$CALL]" >&2
    <<< "${JSON[@]}" jq --arg call "$CALL" '.args=.args.args | .call=$call' \
        | "$UNIPLAY" -f "$CALL" \
        | mapfile JSON

    NOSELECTOR=1
fi

<<< "${JSON[@]}" jq -r '.title' \
    | read -r TBLNAME

DB="$XDG_CACHE_HOME/uniplay.db"

echo "marksel: Find info [$TBLNAME] from db $DB" >&2
sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS '$TBLNAME' (hash CHAR(32) PRIMARY KEY);" >&2
# Move `select ... where` into the loop below
sqlite3 "$DB" "SELECT hash FROM '$TBLNAME';" \
    | mapfile -t HASHES

{
    <<< "${JSON[@]}" jq 'del(.items)'

    <<< "${JSON[@]}" jq --raw-output0 '.items[]' \
        | while IFS= read -r -d $'\0' JSN; do
            MARK="(new)"
            <<< "${JSN}" jq -j .item | md5sum | cut -c -32 | read -r ITEMHASH
            if [[ " ${HASHES[*]} " =~ " $ITEMHASH " ]]; then
                MARK="(seen)"
            fi

            <<< "${JSN}" jq --arg mark "$MARK" --arg hash "$ITEMHASH" '.mark=$mark | .hash=$hash'
        done  \
            | jq -s '{items: .}'

    if [[ -n "$CALL" ]]; then
        <<< "${JSON[@]}" jq '{call: "marksel", args: {call, args}}'
    fi
} \
    | jq -s add \
    | mapfile JSON

if [[ "$NOSELECTOR" -eq 1 ]]; then
    printf "%s" "${JSON[@]}"
else
    <<< "${JSON[@]}" "$UNIPLAY" -f selector \
        | mapfile JSON

    <<< "${JSON[@]}" jq -r .hash \
        | read -r HASH

    echo "marksel: Update $HASH in [$TBLNAME] ($DB)" >&2
    sqlite3 "$DB" "INSERT INTO '$TBLNAME' (hash) VALUES ('$HASH');" >&2

    <<< "${JSON[@]}" jq 'del(.hash)'
fi
