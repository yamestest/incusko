#!/bin/bash
echo "Content-Type: application/json"
echo

NAME=$(echo "$QUERY_STRING" | sed -n 's/^.*name=\([^&]*\).*$/\1/p')
DATE=$(date +"%Y-%m-%d_%H-%M")

SNAP="${NAME}-snap-${DATE}"

export HOME=/home/incusko

if sudo -u incusko incus snapshot create "$NAME" "$SNAP" &>/dev/null; then
  echo "{\"status\":\"success\",\"snapshot\":\"$SNAP\"}"
else
  echo "{\"status\":\"error\",\"message\":\"Nepodarilo sa vytvoriť snapshot\"}"
fi
