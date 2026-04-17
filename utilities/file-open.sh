#!/usr/bin/env bash
set -e
shopt -s lastpipe

which jq xdg-open xargs > /dev/null

jq --raw-output0 .file \
    | xargs -0 -o xdg-open
