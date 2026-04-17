#!/usr/bin/env bash
# Adds `referer` based on current URL in the `item`.
set -e
shopt -s lastpipe

which jq > /dev/null

jq -r '.referer = (.url | split("/")[0:3] | join("/"))'
