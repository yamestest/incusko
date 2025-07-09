#!/bin/bash
echo "Content-Type: application/json"
echo

# --- Vstup ---
NAME=$(echo "$QUERY_STRING" | sed -n 's/^.*name=\([^&]*\).*$/\1/p')
[ -z "$NAME" ] && echo '{"status":"error","message":"missing container name"}' && exit 1

PORT=7701
LOG="/tmp/ttyd-$NAME.log"
export HOME=/home/incusko
##export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin

# --- Zrušiť predchádzajúci ttyd ---
sudo pkill -9 -u incusko -f "ttyd --port $PORT"
sleep 1


# --- Zisti shell ---
if [ "$NAME" = "incusko" ]; then
  SHELL="bash"
  CMD="$SHELL"
##  CMD="bash --init-file <(echo 'cd /home/incusko')"
  PORT=7702
else
  if sudo -u incusko incus exec "$NAME" -- which bash >/dev/null 2>&1; then
    SHELL="bash"
  else
    SHELL="sh"
  fi
  CMD="incus exec $NAME -- $SHELL"
fi


# --- Spusti ttyd ---
sudo -u incusko ttyd --once --port "$PORT" \
  --client-option fontSize=16 \
  --client-option theme=dark \
  --writable $CMD \
  > "$LOG" 2>&1 &

NEWPID=$!

# --- Výstup ---
[ -n "$NEWPID" ] && echo "{\"status\":\"success\",\"name\":\"$NAME\",\"port\":$PORT,\"pid\":$NEWPID}" || echo '{"status":"error","message":"ttyd failed to start"}'

