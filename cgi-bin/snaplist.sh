#!/bin/bash
echo "Content-Type: application/json"
echo

NAME=$(echo "$QUERY_STRING" | sed -n 's/^.*name=\([^&]*\).*$/\1/p')
export HOME=/home/incusko

SNAPS=$(sudo -u incusko incus snapshot list "$NAME" --format csv | tail -n +2)

echo "["
FIRST=true
while IFS=',' read -r SNAP TAKEN EXPIRES STATEFUL; do
  [ "$FIRST" = false ] && echo ","
  FIRST=false

  # Opravíme expires — ak je prázdne, nastavíme ako null
if [[ "$EXPIRES" =~ ^\"?\ ?\"?$ ]]; then
  EXPIRES_JSON=null
else
  SAFE_EXPIRES=$(echo "$EXPIRES" | sed 's/"/\\"/g')
  EXPIRES_JSON="\"$SAFE_EXPIRES\""
fi

  # Escape aj ostatné polia pre istotu
  SNAP_JSON=$(printf '%s\n' "$SNAP" | sed 's/"/\\"/g')
  TAKEN_JSON=$(printf '%s\n' "$TAKEN" | sed 's/"/\\"/g')
  STATEFUL_JSON=$(printf '%s\n' "$STATEFUL" | sed 's/"/\\"/g')

  echo -n "{\"name\":\"$SNAP_JSON\",\"taken\":\"$TAKEN_JSON\",\"expires\":$EXPIRES_JSON,\"stateful\":\"$STATEFUL_JSON\"}"
done <<< "$SNAPS"
echo "]"
