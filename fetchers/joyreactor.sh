#!/usr/bin/env bash
set -e

which jq grep http > /dev/null

mapfile -t JSON
read -r URL < <(jq -r .url <<< "${JSON[@]}")

[[ "$URL" =~ [^/]+://[^/]+/tag/([^/]+)/?([0-9]+)?/? ]]
TAGNAME="${BASH_REMATCH[1]}"
PAGE="${BASH_REMATCH[2]}"
URLS=()
while ((${#URLS[@]} < 12)); do
    if [[ -n "$PAGE" ]]; then
        PAGEPATTERN="(page: $PAGE)"
    fi

    echo "joyreactor: Extract tag [$TAGNAME] from page [${PAGE:-inf}]" >&2

    readarray -t REQUEST <<EOF
{
    tag(name: \"$TAGNAME\") {
        postPager(type: ALL) {
            count
            id
            posts $PAGEPATTERN {
                id
                tags {
                    name
                }
                attributes {
                    id
                    type
                    ... on PostAttributePicture {
                        image {
                            type
                        }
                    }
                    ... on PostAttributeEmbed {
                        value
                    }
                }
            }
        }
    }
}
EOF

    mapfile -t JSON < <(printf "%s" '{"query": "' "${REQUEST[@]}" '"}' | http POST https://api.joyreactor.cc/graphql)

    if [[ -n "$PAGE" ]]; then
        ((PAGE--))
    else
        read -r PAGE < <(jq -r '.data.tag.postPager.count' <<< "${JSON[@]}")
        echo "joyreactor: The last page $((PAGE / 10)) [$PAGE]" >&2
        PAGE=$((PAGE / 10 - 1))
    fi

    while read -r ID IMGTYPE PREFIX; do
        if [[ "$IMGTYPE" == jpeg || "$IMGTYPE" == png ]]; then
            URLS+=("https://img10.joyreactor.cc/pics/post/${PREFIX}-${ID}.${IMGTYPE}")
        fi
    done < <(jq -r '.data.tag.postPager.posts[]
                    | select(.attributes[0].type == "PICTURE") |
                        [
                            (.attributes[0] | (.id | @base64d | split(":")[-1]),(.image.type | ascii_downcase)),
                            (.tags[:3] | map(.name | gsub(" |/|#"; "-")) | join("-"))
                        ] | @tsv' <<< "${JSON[@]}")
done

jo result=urls urls=$(jo -a "${URLS[@]}")
