#!/bin/sh

if [ -z "$1" ]; then
  echo "Použitie: $0 <nazov_kontajnera> [port] [cpu] [pamät]"
  exit 1
fi

CONTAINER_NAME="$1"
HTTP_PORT="${2:-8080}"
CPU_LIMIT="${3:-1}"
MEMORY_LIMIT="${4:-512MiB}"

PROFILE_NAME="wp-internal"
POOL_NAME="incusko"
NETWORK_NAME="incusbr0"
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS="wp123"

# 🌐 Sieť
if ! incus network show "$NETWORK_NAME" >/dev/null 2>&1; then
  incus network create "$NETWORK_NAME" ipv4.address=10.42.42.1/24 ipv4.nat=true ipv6.address=none
fi

# 🧱 Profil
if ! incus profile show "$PROFILE_NAME" >/dev/null 2>&1; then
  incus profile create "$PROFILE_NAME"
  incus profile device add "$PROFILE_NAME" root disk pool="$POOL_NAME" path=/
  incus profile device add "$PROFILE_NAME" eth0 nic nictype=bridged parent="$NETWORK_NAME" name=eth0
fi

# 🚀 Kontajner
incus launch images:alpine/3.20/cloud "$CONTAINER_NAME" --profile "$PROFILE_NAME"

# ⚙️ Limity
incus config set "$CONTAINER_NAME" limits.cpu="$CPU_LIMIT"
incus config set "$CONTAINER_NAME" limits.memory="$MEMORY_LIMIT"
incus config set "$CONTAINER_NAME" limits.memory.enforce=hard

# 🔗 Proxy
incus config device add "$CONTAINER_NAME" proxy proxy \
  listen=tcp:0.0.0.0:$HTTP_PORT \
  connect=tcp:127.0.0.1:$HTTP_PORT

sleep 6

# 🛠️ Inštalácia vo vnútri kontajnera
incus exec "$CONTAINER_NAME" -- sh -c "
apk update
apk add nginx php82 php82-fpm php82-mysqli php82-session php82-xml php82-gd php82-curl php82-mbstring php82-json mariadb mariadb-client openrc curl unzip

mysql_install_db --user=mysql --datadir=/var/lib/mysql
touch /run/openrc/softlevel

rc-service mariadb start
rc-service php-fpm82 start
rc-service nginx start

rc-update add mariadb default
rc-update add php-fpm82 default
rc-update add nginx default

mysql -uroot -e \"
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
\"

mkdir -p /var/www/html

curl -LO https://wordpress.org/latest.zip
unzip latest.zip -d /tmp/
cp -r /tmp/wordpress/* /var/www/html/
rm -rf /tmp/wordpress latest.zip

cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i \"s/database_name_here/$DB_NAME/\" /var/www/html/wp-config.php
sed -i \"s/username_here/$DB_USER/\" /var/www/html/wp-config.php
sed -i \"s/password_here/$DB_PASS/\" /var/www/html/wp-config.php

echo 'server {
  listen $HTTP_PORT;
  server_name _;

  root /var/www/html;
  index index.php index.html;

  location / {
    try_files \$uri \$uri/ /index.php?\$args;
  }

  location ~ \\.php\$ {
    include fastcgi_params;
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
  }
}' > /etc/nginx/http.d/wp.conf

rc-service nginx restart
"

# 📣 Výstup
HOST_IP=$(hostname -I | awk '{print $1}')
echo "✅ WordPress kontajner '$CONTAINER_NAME' nasadený!"
echo "🌐 Otvor: http://$HOST_IP:${HTTP_PORT}/"
echo "🗄️ DB: $DB_NAME | Užívateľ: $DB_USER | Heslo: $DB_PASS"
echo "🧠 CPU: $CPU_LIMIT | RAM: $MEMORY_LIMIT"
echo "📦 Inštalácia: čistá vo vnútri kontajnera (žiadne mounty)"

