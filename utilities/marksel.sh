#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq sqlite3 md5sum cut > /dev/null

mapfile JSON
<<< "${JSON[@]}" jq -r '.title, (.hashkey // "title")' \
    | { read -r TBLNAME; read -r HASHKEY; }

DB="$XDG_CACHE_HOME/uniplay.db"

# Escape single quote
<<< "$TBLNAME" sed "s;';'';g" \
    | read -r TBLNAME

echo "marksel: Find info [$TBLNAME] from db $DB" >&2
sqlite3 -batch "$DB" "CREATE TABLE IF NOT EXISTS '$TBLNAME' (hash CHAR(32) PRIMARY KEY);" >&2

{
    <<< "${JSON[@]}" jq 'del(.list)'
    <<< "${JSON[@]}" jq --raw-output0 '.list[]' \
        | while IFS= read -r -d $'\0' JSN; do
            if ! <<< "${JSN}" jq -r '.hash // empty' | read -r ITEMHASH; then
                <<< "${JSN}" jq -j ".$HASHKEY" \
                    | md5sum \
                    | cut -c -32 \
                    | read -r ITEMHASH
            fi

            sqlite3 -batch "$DB" "SELECT EXISTS(SELECT 1 FROM '$TBLNAME' WHERE hash = '$ITEMHASH')" \
                | read -r RESULT
            if [[ "$RESULT" -eq 1 ]]; then
                MARK="(seen)"
            else
                MARK="(new)"
            fi

            <<< "${JSN}" jq --arg mark "$MARK" --arg hash "$ITEMHASH" '.mark=$mark | .hash=$hash'
        done  \
            | jq -s '{list: .}'
} \
    | jq -s add \
    | "$UNIPLAY" selector \
    | mapfile JSON

<<< "${JSON[@]}" jq -r .hash \
    | read -r HASH

echo "marksel: Update [$HASH] in [$TBLNAME] ($DB)" >&2
sqlite3 "$DB" "INSERT OR IGNORE INTO '$TBLNAME' (hash) VALUES ('$HASH');" >&2

printf "%s" "${JSON[@]}"
