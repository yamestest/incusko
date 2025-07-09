#!/bin/bash
set -euo pipefail

# Overenie, či bežíme ako root
if [ "$(id -u)" -ne 0 ]; then
  echo "Spustite ako root" >&2
  exit 1
fi

# 1) Aktualizácia balíkov a inštalácia mini-httpd + incus-base
apt-get update
apt-get install -y mini-httpd incus-base

# 1a) Inštalácia ttyd (binárka podľa architektúry)  
URL_BASE="https://github.com/tsl0922/ttyd/releases/download/1.7.4"  
ARCH=$(uname -m)  
case "$ARCH" in  
  x86_64)  FILE="ttyd.x86_64"  ;;  
  aarch64) FILE="ttyd.aarch64" ;;  
  armv7l)  FILE="ttyd.armv7l"  ;;  
  *)  
    echo "❌ Nepodporovaná architektúra: $ARCH" >&2  
    exit 1  
    ;;  
esac  

wget -qO ttyd "$URL_BASE/$FILE"  
chmod +x ttyd  
mv ttyd /usr/local/sbin/ttyd

# 2) Vytvorenie skupiny a používateľa incusko bez hesla
groupadd -f incus-admin
if ! id incusko &>/dev/null; then
  useradd -m -s /bin/bash incusko
  passwd -d incusko
fi

# 3) Pridanie incusko do skupiny incus-admin
usermod -aG incus-admin incusko

# 4) Pridanie „cd /home/incusko“ do .bashrc používateľa incusko
BASHRC=/home/incusko/.bashrc
if ! grep -qx 'cd /home/incusko' "$BASHRC"; then
  echo 'cd /home/incusko' >> "$BASHRC"
  chown incusko:incusko "$BASHRC"
fi

# 5) Dopísanie sudoers pravidiel pre www-data
cat <<EOF >/etc/sudoers.d/incusko
www-data ALL=(incusko) NOPASSWD: /usr/bin/incus, /usr/local/sbin/ttyd
www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill
EOF
chmod 440 /etc/sudoers.d/incusko

# 6) Nasadenie systemd servisu pre mini_httpd
cp install/mini_httpd.service /etc/systemd/system/mini_httpd.service
systemctl daemon-reload
systemctl enable mini_httpd
systemctl start mini_httpd

# 7) Vytvorenie webroot a CGI adresárov
mkdir -p /var/www/incusko/cgi-bin

# 8) Kopírovanie frontendu (*.html, *.js)
cp -a ./*.html ./*.js /var/www/incusko/

# 9) Kopírovanie CGI skriptov a nastavenie práv
cp -a ./cgi-bin/* /var/www/incusko/cgi-bin/
chmod +x /var/www/incusko/cgi-bin/*.sh

# 10) Nastavenie vlastníka webrootu
chown -R www-data:www-data /var/www/incusko

echo "Inštalácia dokončená."
