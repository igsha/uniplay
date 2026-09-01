#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq http >/dev/null

jq -r .url \
    | read -r URL

if [[ "$URL" =~ [^/]+://([^/]+)/post/([0-9]+) ]]; then
    DOMAIN="${BASH_REMATCH[1]}"
    POSTID="${BASH_REMATCH[2]}"
    echo "joyreactor: Extract post images from $URL" >&2

    echo -n "Post:$POSTID" \
        | base64 \
        | read -r BID

    readarray -t REQUEST <<EOF
query IdPostPageQuery(\$id: ID!) {
    node(id: \$id) {
        ... on Post {
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
            tags {
                name
            }
        }
    }
}
EOF

    printf "%s" "${REQUEST[@]}" \
        | jq -Rs --arg bid "$BID" '{query: ., variables: {id: $bid}}' \
        | http POST "https://api.${DOMAIN}/graphql" \
        | jq '[.data.node]' \
        | mapfile JSON

elif [[ "$URL" =~ [^/]+://([^/]+)/tag/([^/]+)/?([0-9]+)? ]]; then
    DOMAIN="${BASH_REMATCH[1]}"
    TAGNAME="${BASH_REMATCH[2]}"
    PAGE="${BASH_REMATCH[3]}"
    if [[ -n "$PAGE" ]]; then
        PAGEPATTERN="(page: $PAGE)"
    fi

    echo "joyreactor: Extract tag [$TAGNAME] from page [${PAGE:-inf}]" >&2

    readarray -t REQUEST <<EOF
{
    tag(name: "$TAGNAME") {
        postPager(type: ALL) {
            count
            posts $PAGEPATTERN {
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

    printf "%s" "${REQUEST[@]}" \
        | jq -Rs '{query: .}' \
        | http POST "https://api.${DOMAIN}/graphql" \
        | mapfile JSON

    <<< "${JSON[@]}" jq -r '.data.tag.postPager.count' \
        | read -r NUM

    if [[ -z "$PAGE" ]]; then
        PAGE=$((NUM / 10))
    fi

    echo "joyreactor: Read page $PAGE [$NUM posts]" >&2
    <<< "${JSON[@]}" jq '.data.tag.postPager.posts' \
        | mapfile JSON
else
    echo "joyreactor: Unsupported url $URL" >&2
    exit 1
fi

echo "joyreactor: Extract names" >&2
<<< "${JSON[@]}" jq -r '.[] |
        (.tags[:3] | map(.name | gsub(" |/|#|\\?"; "-")) | join("-")) as $prefix |
        .attributes[] | select(.type == "PICTURE" or .type == "VIDEO") |
            (.id | @base64d | split(":")[-1]) as $id |
            (.image.type | ascii_downcase) as $imgtype |
            "\($prefix)-\($id).\($imgtype)"' \
    | readarray -t NAMES

echo "joyreactor: Convert ${#NAMES[@]} names into urls" >&2
printf "%s\n" "${NAMES[@]}" \
    | jq --arg base "$DOMAIN" -Rn '[inputs] | map({
            url: "https://img10.\($base)/pics/post/\(.)",
            title: .,
            fallback: "https://img2.\($base)/pics/post/\(.)"
        }) | {
            list: .,
            title: "joyreactor",
            hashkey: "url",
            referer: "https://joyreactor.cc/",
            type: "images",
            pipeline: "film"
        }'
