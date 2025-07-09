#!/bin/bash
echo "Content-Type: application/json"
echo

# Získaj parametre z QUERY_STRING
CMD=$(echo "$QUERY_STRING" | sed -n 's/^.*cmd=\([^&]*\).*$/\1/p')
NAME=$(echo "$QUERY_STRING" | sed -n 's/^.*name=\([^&]*\).*$/\1/p')

# Nastav HOME a spusti ako incusko
export HOME=/home/incusko
if sudo -u incusko incus "$CMD" "$NAME" 2>/dev/null; then
  echo "{\"status\":\"success\",\"action\":\"$CMD\",\"name\":\"$NAME\"}"
else
  echo "{\"status\":\"error\",\"message\":\"failed to execute $CMD on $NAME\"}"
fi

