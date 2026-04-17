#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq >/dev/null

trap 'echo "autotest: FAILED ${BASH_SOURCE}:${LINENO}"' ERR

takeidx() {
    jq --argjson idx "$1" '. + add(.list[$idx]) | del(.list)' \
    | "$UNIPLAY" auto
}

takelastfirst() {
    takeidx -1 | takeidx 0
}

iscontenttext() {
    jq -e 'has("content") and .type == "text"' >/dev/null
}

ism3u8video() {
    jq -e '(.url | test("\\.m3u8")) and .type == "video"' >/dev/null
}

ismanga() {
    jq -e '.type == "images" and .pipeline == "manga"' >/dev/null
}

export -f takeidx takelastfirst iscontenttext ism3u8video ismanga

CHAIN="$XDG_CONFIG_HOME/uniplay/autotest.sh"
if [[ -x "$CHAIN" ]]; then
    echo "autotest: Test $CHAIN" >&2
    "$CHAIN"
fi

# vkvideo
"$UNIPLAY" auto "https://vkvideo.ru/playlist/-50148160_1" \
    | takeidx 0 \
    | jq -e '(.url | test("okcdn.ru")) and .type == "video"' \
    >/dev/null

# rutube
"$UNIPLAY" auto "https://rutube.ru/plst/196238/" \
    | takelastfirst \
    | ism3u8video

# substack
"$UNIPLAY" auto "https://substack.com/home/post/p-183538018" \
    | jq -e '(.url | test("type=hls")) and .type == "video"' \
    >/dev/null

# obrut movie
"$UNIPLAY" auto "https://44baba96.obrut.show/embed/wN/content/MDNwkTN?dubbing=(RU) MVO | LostFilm" \
    | ism3u8video

# obrut serial
"$UNIPLAY" auto "https://44baba96.obrut.show/embed/wN/content/IjN1QzN?dubbing=(RU) DVO | НТВ" \
    | takeidx 0 \
    | ism3u8video

# joyreactor
"$UNIPLAY" auto "https://joyreactor.cc/tag/котэ" \
    | jq -e '(.list[0].url | test("joyreactor")) and .type == "images" and .pipeline == "film"' \
    >/dev/null

# cnews
"$UNIPLAY" auto "https://cnews.ru" \
    | takeidx 0 \
    | iscontenttext

# opennet
"$UNIPLAY" auto "https://www.opennet.ru/opennews/" \
    | takelastfirst \
    | iscontenttext

# manga-shi
"$UNIPLAY" auto "https://manga-shi.org/manga/apex-future-martial-arts/" \
    | takelastfirst \
    | ismanga

# seimanga
"$UNIPLAY" auto "https://1.seimanga.me/kaidziu_no__8" \
    | takeidx 0 \
    | ismanga

# mangaonelove
"$UNIPLAY" auto "https://mangaonelove.space/manga/vanpanchmen-sajtama-protiv-boga/" \
    | takeidx 0 \
    | ismanga

# mangalib
"$UNIPLAY" auto "https://mangalib.me/ru/manga/7795--hataraku-saibou" \
    | takeidx 0 \
    | ismanga

# remanga
"$UNIPLAY" auto "https://remanga.org/manga/one-punchman-fan-colored/main" \
    | takelastfirst \
    | ismanga

# yummyani
"$UNIPLAY" auto "https://site.yummyani.me/catalog/item/doktor-stoun-nauchnoe-buduschee-chast-3" \
    | mapfile JSON

# cdnvideohub
<<< "${JSON[@]}" jq '.list[] | select(.title| test("CVH"))' \
    | "$UNIPLAY" auto \
    | takeidx 0 \
    | jq -e '.list[0].url | test("https://.*?cdnvideohub\\.com/api/v1/player/sv/video/\\d+")' \
    >/dev/null

# kodik
<<< "${JSON[@]}" jq '.list[] | select(.title| test("Kodik"; "i"))' \
    | "$UNIPLAY" auto \
    | takeidx 0 \
    | jq -e '.list[0].url | test("https://*?kodik.*?\\.com/ftor\\?type=\\w+&id=\\d+&hash=\\w+")' \
    >/dev/null

echo "autotest: DONE" >&2
