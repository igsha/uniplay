#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq jo sqlite3 fzf md5sum cut > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.items[]' \
    | mapfile -t ITEMS

<<< "${JSON[@]}" jq -r '.names[]' \
    | mapfile -t NAMES

<<< "${JSON[@]}" jq -r '.title' \
    | read -r TBLNAME

DB="$XDG_CACHE_HOME/uniplay.db"

echo "marksel: Find info [$TBLNAME] from db $DB" >&2
sqlite3 "$DB" "create table if not exists '$TBLNAME' (hash char(32));" >&2
sqlite3 "$DB" "select hash from '$TBLNAME';" \
    | mapfile -t HASHES

for i in "${!ITEMS[@]}"; do
    MARK="(new)"
    <<< "${ITEMS[$i]}" md5sum | cut -c -32 | read -r ITEMHASH
    if [[ " ${HASHES[*]} " =~ " $ITEMHASH " ]]; then
        MARK="(seen)"
    fi

    printf '%s\t%s\t%s\t%s\n' "$MARK" "${NAMES[$i]}" "$ITEMHASH" "${ITEMS[$i]}"
done \
    | fzf -d $'\t' --with-nth=1,2 --accept-nth=2,3,4 \
    | IFS=$'\t' read -r NAME HASH ITEM


echo "marksel: Update db $DB" >&2
sqlite3 "$DB" "insert into '$TBLNAME' (hash) values ('$HASH');" >&2

jo result=list item="$ITEM" title="$NAME"
