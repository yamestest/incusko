#!/bin/bash
echo "Content-Type: application/json"
echo

NAME=$(echo "$QUERY_STRING" | sed -n 's/^.*name=\([^&]*\).*$/\1/p')
SNAP=$(echo "$QUERY_STRING" | sed -n 's/^.*snap=\([^&]*\).*$/\1/p')

export HOME=/home/incusko

if sudo -u incusko incus snapshot restore "$NAME" "$SNAP" &>/dev/null; then
  echo "{\"status\":\"success\",\"message\":\"Snapshot '$SNAP' bol obnovený.\"}"
else
  echo "{\"status\":\"error\",\"message\":\"Nepodarilo sa obnoviť snapshot '$SNAP'.\"}"
fi
