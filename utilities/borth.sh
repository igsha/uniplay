#!/usr/bin/env bash
set -e
shopt -s lastpipe

read -r BORTH1
echo "borth: borth1=$BORTH1" >&2

BORTH2="${BORTH1:87:1}${BORTH1:86:1}${BORTH1:84:2}${BORTH1:80:4}${BORTH1:72:8}${BORTH1:56:16}${BORTH1:24:32}${BORTH1:0:24}"
echo "borth: borth2=$BORTH2" >&2

declare -a ARR
ARR[0]="${BORTH2: -1:1}"
for ((n=0, k=0; n < 7; ++n)); do
    for ((i=1<<n; i < ${#BORTH2}; i+=1<<(n+1), ++k)); do
        ARR[$i]=${BORTH2:$k:1}
    done
done
printf -v BORTH3 "%s" "${ARR[@]}"
echo "borth: borth3=$BORTH3" >&2

ARR=("${BORTH3: -1:1}")
for ((i=2, k=0; i < ${#BORTH3}; i+=2, ++k)); do
    ARR[$i]="${BORTH3:$k:1}"
done
for ((i=1; i < ${#BORTH3}; i+=2, ++k)); do
    ARR[$i]="${BORTH3:$k:1}"
done
printf -v BORTH4 "%s" "${ARR[@]}"
echo "borth: borth4=$BORTH4" >&2

echo "$BORTH4"
