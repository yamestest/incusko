#!/bin/bash
echo "Content-Type: application/json"
echo

# Získaj parametre z QUERY_STRING
name=$(echo "$QUERY_STRING" | sed -n 's/.*name=\([^&]*\).*/\1/p' | sed 's/%20/ /g')
snap=$(echo "$QUERY_STRING" | sed -n 's/.*snap=\([^&]*\).*/\1/p' | sed 's/%20/ /g')

# Over či sú parametre zadané
if [ -z "$name" ] || [ -z "$snap" ]; then
  echo '{"status":"error","message":"Chýba parameter name alebo snap"}'
  exit 1
fi

export HOME=/home/incusko

# Pokus o zmazanie snapshotu
if sudo -u incusko incus snapshot delete "$name" "$snap" 2>/dev/null; then
  echo "{\"status\":\"success\",\"message\":\"Snapshot '$snap' zmazaný\"}"
else
  echo "{\"status\":\"error\",\"message\":\"Zmazanie snapshotu zlyhalo\"}"
fi

