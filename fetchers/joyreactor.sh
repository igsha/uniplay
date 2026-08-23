#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq grep http >/dev/null

jq -r .url \
    | read -r URL

if [[ "$URL" =~ /post/[0-9]+ ]]; then
    echo "joyreactor: Extract post images from $URL" >&2
    http GET "$URL" \
        | htmlq -p '.post-content img' -a src \
        | jq -Rn '[inputs] | {
            list: map({url: .}),
            title: "joyreactor",
            hashkey: "url",
            referer: "https://joyreactor.cc/",
            type: "images",
            pipeline: "film"
        }'
elif [[ "$URL" =~ [^/]+://([^/]+)/tag/([^/]+)/?([0-9]+)? ]]; then
    DOMAIN="${BASH_REMATCH[1]}"
    TAGNAME="${BASH_REMATCH[2]}"
    PAGE="${BASH_REMATCH[3]}"
    URLS=()
    while ((${#URLS[@]} < 10)); do
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

        printf "%s" '{"query": "' "${REQUEST[@]}" '"}' \
            | http POST "https://api.${DOMAIN}/graphql" \
            | mapfile JSON

        if [[ -z "$PAGE" ]]; then
            <<< "${JSON[@]}" jq -r '.data.tag.postPager.count' \
                | read -r NUM
            PAGE=$((NUM / 10))
            echo "joyreactor: The last page $PAGE [$NUM]" >&2
        fi

        ((PAGE--))

        <<< "${JSON[@]}" jq -r '.data.tag.postPager.posts[] | select(.attributes[0] | .type == "PICTURE" or .type == "VIDEO")
                    | (.tags[:3] | map(.name | gsub(" |/|#|\\?"; "-")) | join("-")) as $prefix
                    | .attributes[0] | (.id | @base64d | split(":")[-1]) as $id | (.image.type | ascii_downcase) as $imgtype
                    | "\($prefix)-\($id).\($imgtype)"' \
            | readarray -t -O "${#URLS[@]}" URLS
    done

    echo "joyreactor: Read ${#URLS[@]} names ($LIMIT)" >&2
    jo -a "${URLS[@]}" \
        | jq --arg base "$DOMAIN" '{
            list: map({url: "https://img10.\($base)/pics/post/\(.)", title: ., fallback: "https://img2.\($base)/pics/post/\(.)"}),
            title: "joyreactor",
            hashkey: "url",
            referer: "https://joyreactor.cc/",
            type: "images",
            pipeline: "film"
        }'
else
    echo "joyreactor: Unsupported url $URL" >&2
    exit 1
fi
