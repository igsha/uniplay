#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq sqlite3 fzf > /dev/null

mapfile -t JSON
<<< "${JSON[@]}" jq -r '.items[]' \
    | mapfile -t ITEMS

<<< "${JSON[@]}" jq -r '.names[]' \
    | mapfile -t NAMES

<<< "${JSON[@]}" jq -r '.title' \
    | read -r TBLNAME

DB="$XDG_CACHE_HOME/uniplay.db"

echo "marksel: Find info [$TBLNAME] from db $DB" >&2
sqlite3 "$DB" "create table if not exists '$TBLNAME' (name str);" >&2
sqlite3 "$DB" "select name from '$TBLNAME';" \
    | mapfile -t NAMESINTABLE

for i in "${!ITEMS[@]}"; do
    MARK="(new)"
    if [[ " ${NAMESINTABLE[*]} " =~ " ${NAMES[$i]} " ]]; then
        MARK="(seen)"
    fi

    printf '%s\t%s\t%s\n' "$MARK" "${NAMES[$i]}" "${ITEMS[$i]}"
done \
    | fzf -d $'\t' --with-nth=1,2 --accept-nth=2,3 \
    | IFS=$'\t' read -r NAME ITEM


echo "marksel: Update db $DB" >&2
sqlite3 "$DB" "insert into '$TBLNAME' (name) values ('$NAME');" >&2

export NAME ITEM
<<< "${JSON[@]}" jq '.item=env.ITEM | .title=env.NAME | del(.names) | del(.items)'
