#!/usr/bin/env bash
# Adds `referer` based on current URL in the `item`.
set -e
shopt -s lastpipe

which jq > /dev/null

jq -r '.referer = (.item | split("/")[0:3] | join("/"))'
