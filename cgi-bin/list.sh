#!/bin/bash
echo "Content-Type: application/json"
echo

export HOME=/home/incusko

echo "["
FIRST=true
for NAME in $(sudo -u incusko incus list -c n --format csv); do
  STATUS=$(sudo -u incusko incus list "$NAME" -c s --format csv)
  IPV4=$(sudo -u incusko incus list "$NAME" -c 4 --format csv)
  TYPE=$(sudo -u incusko incus list "$NAME" -c t --format csv)
  SNAP=$(sudo -u incusko incus snapshot list "$NAME" --format csv | wc -l)

  CPU=$(sudo -u incusko incus config get "$NAME" limits.cpu)
  RAM=$(sudo -u incusko incus config get "$NAME" limits.memory)

  CPU_JSON=$( [ -n "$CPU" ] && echo "\"$CPU\"" || echo "null" )
  RAM_JSON=$( [ -n "$RAM" ] && echo "\"$RAM\"" || echo "null" )

  [ "$FIRST" = false ] && echo ","
  FIRST=false

  echo -n "{\"name\":\"$NAME\",\"status\":\"$STATUS\",\"ipv4\":\"$IPV4\",\"type\":\"$TYPE\""
  echo -n ",\"cpu\":$CPU_JSON,\"ram\":$RAM_JSON"
  echo -n ",\"snapshots\":$SNAP}"

done
echo "]"

