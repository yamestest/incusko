#!/bin/bash
set -euo pipefail

# Overenie root
if [ "$(id -u)" -ne 0 ]; then
  echo "Spustite ako root" >&2
  exit 1
fi

# 1) Aktualizácia a inštalácia mini-httpd + incus-base
apt-get update
apt-get install -y mini-httpd incus-base

# 2) Inštalácia ttyd (latest)
URL_BASE="https://github.com/tsl0922/ttyd/releases/latest/download"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  FILE="ttyd.x86_64"  ;;
  aarch64) FILE="ttyd.aarch64" ;;
  armv7l)  FILE="ttyd.armv7l"  ;;
  *) echo "❌ Nepodporovaná architektúra: $ARCH" >&2; exit 1 ;;
esac

wget -qO /usr/local/sbin/ttyd "$URL_BASE/$FILE"
chmod +x /usr/local/sbin/ttyd

# 3) Vytvorenie skupiny a používateľa incusko
groupadd -f incus-admin
if ! id incusko &>/dev/null; then
  useradd -m -s /bin/bash incusko
  passwd -d incusko
fi

# 4) Pridanie incusko do incus-admin
usermod -aG incus-admin incusko

# 5) Pridanie cd do .bashrc
BASHRC=/home/incusko/.bashrc
if ! grep -qx 'cd /home/incusko' "$BASHRC"; then
  echo 'cd /home/incusko' >> "$BASHRC"
  chown incusko:incusko "$BASHRC"
fi

# 6) Sudoers pre www-data
cat <<EOF >/etc/sudoers.d/incusko
www-data ALL=(incusko) NOPASSWD: /usr/bin/incus, /usr/local/sbin/ttyd
www-data ALL=(ALL)       NOPASSWD: /usr/bin/pkill
EOF
chmod 440 /etc/sudoers.d/incusko

# 7) Deploy mini_httpd.service
cp install/mini_httpd.service /etc/systemd/system/mini_httpd.service
systemctl daemon-reload
systemctl enable mini_httpd
systemctl start mini_httpd

# 8) Vytvorenie webroot a CGI adresára
mkdir -p /var/www/incusko/cgi-bin

# 9) Kopírovanie frontendu (*.html, *.js)
cp -a ./*.html ./*.js /var/www/incusko/

# 10) Kopírovanie CGI skriptov
cp -a ./cgi-bin/* /var/www/incusko/cgi-bin/
chmod +x /var/www/incusko/cgi-bin/*.sh

# 11) Kopírovanie obsahu priečinka scripts do /home/incusko
if [ -d ./scripts ]; then
  cp -a ./scripts/* /home/incusko/
  chown -R incusko:incusko /home/incusko
fi

# 12) Nastavenie vlastníka webrootu
chown -R www-data:www-data /var/www/incusko

echo "Inštalácia dokončená."
