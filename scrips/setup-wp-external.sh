#!/bin/sh

if [ -z "$1" ]; then
  echo "Použitie: $0 <wp_kontajner> [http_port] [db_kontajner] [db_password] [cpu_limit] [mem_limit]"
  exit 1
fi

WP_NAME="$1"
HTTP_PORT="${2:-8080}"
DB_CONTAINER="${3:-db-mariadb}"
DB_PASS="${4:-wp123}"
CPU_LIMIT="${5:-2}"
MEM_LIMIT="${6:-512MiB}"
DB_NAME="wp_${WP_NAME}"
DB_USER="wpuser"
PROFILE_NAME="wp-profile"
POOL_NAME="incusko"
NETWORK_NAME="incusbr0"

# 🌐 Sieť
if ! incus network show "$NETWORK_NAME" >/dev/null 2>&1; then
  incus network create "$NETWORK_NAME" ipv4.address=10.42.42.1/24 ipv4.nat=true ipv6.address=none
fi

# 📦 Profil
if ! incus profile show "$PROFILE_NAME" >/dev/null 2>&1; then
  incus profile create "$PROFILE_NAME"
  incus profile device add "$PROFILE_NAME" root disk pool="$POOL_NAME" path=/
  incus profile device add "$PROFILE_NAME" eth0 nic nictype=bridged parent="$NETWORK_NAME" name=eth0
fi

# 🚀 WP kontajner
incus launch images:alpine/3.20/cloud "$WP_NAME" --profile "$PROFILE_NAME"

# 🔧 Nastav limity výkonu
incus config set "$WP_NAME" limits.cpu "$CPU_LIMIT"
incus config set "$WP_NAME" limits.memory "$MEM_LIMIT"

# 🔗 Proxy
incus config device add "$WP_NAME" proxy proxy \
  listen=tcp:0.0.0.0:$HTTP_PORT \
  connect=tcp:127.0.0.1:$HTTP_PORT

sleep 6

# 📡 IP databázového kontajnera
DB_IP=$(incus exec "$DB_CONTAINER" -- ip -4 addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1)

# 🗄️ Vytvor DB vo vzdialenej Mariadb
incus exec "$DB_CONTAINER" -- sh -c "
mysql -uroot -e \"
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;\"
"

# 🛠️ Inštalácia WP
incus exec "$WP_NAME" -- sh -c "
apk update
apk add nginx php82 php82-fpm php82-mysqli php82-session php82-xml php82-gd php82-curl php82-mbstring php82-json mariadb-client openrc curl unzip

touch /run/openrc/softlevel
rc-service php-fpm82 start
rc-service nginx start
rc-update add php-fpm82 default
rc-update add nginx default

mkdir -p /var/www/html
curl -LO https://wordpress.org/latest.zip
unzip -q latest.zip -d /tmp/
cp -r /tmp/wordpress/* /var/www/html/
rm -rf /tmp/wordpress latest.zip
chown -R nginx:nginx /var/www/html

cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i \"s/database_name_here/$DB_NAME/\" /var/www/html/wp-config.php
sed -i \"s/username_here/$DB_USER/\" /var/www/html/wp-config.php
sed -i \"s/password_here/$DB_PASS/\" /var/www/html/wp-config.php
sed -i \"s/localhost/$DB_IP/\" /var/www/html/wp-config.php
echo \"define('FS_METHOD', 'direct');\" >> /var/www/html/wp-config.php

echo 'server {
  listen '"$HTTP_PORT"';
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
echo "✅ WordPress '$WP_NAME' nasadený!"
echo "🌐 Web: http://$(hostname -I | awk '{print $1}'):$HTTP_PORT/"
echo "🗄️ DB: $DB_NAME (v kontajneri $DB_CONTAINER @ $DB_IP)"
echo "👤 Užívateľ: $DB_USER | Heslo: $DB_PASS"
echo "⚙️ Limity: CPU $CPU_LIMIT | RAM $MEM_LIMIT"

