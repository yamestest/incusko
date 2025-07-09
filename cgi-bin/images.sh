#!/bin/bash
echo "Content-Type: application/json"
echo

export HOME=/home/incusko

sudo -u incusko incus image list images: architecture=aarch64 --format=csv | \
grep -E 'debian|ubuntu|alpine' | grep CONTAINER | grep -v cloud | \
cut -d',' -f1 | \
awk 'BEGIN { print "[" } { printf "%s\"images:%s\"", NR==1 ? "" : ",", $1 } END { print "]" }'

