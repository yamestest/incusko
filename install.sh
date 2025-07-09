#!/bin/bash
set -euo pipefail

# Tento skript vytvorí používateľa incusko, nastaví práva, nainštaluje balíky, nasadí mini_httpd a nakopíruje webové súbory.

# Overenie, že bežíme ako root
if [ "$(id -u)" -ne 0 ]; then
  echo "Spustite ako root" >&2
  exit 1
fi

# 1) Vytvorenie používateľa incusko s domácim adresárom, bez hesla
groupadd -f incus-admin
if ! id incusko &>/dev/null; then
  useradd -m -s /bin/bash incusko
fi
passwd -d incusko

# 2) Pridanie incusko do skupiny incus-admin
usermod -aG incus-admin incusko

# 3) Dopísanie sudoers pravidiel pre www-data
cat <<EOF >/etc/sudoers.d/incusko
www-data ALL=(incusko) NOPASSWD: /usr/bin/incus, /usr/local/sbin/ttyd
www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill
EOF
chmod 440 /etc/sudoers.d/incusko

# 4) Inštalácia mini_httpd a incus-base
apt-get update
apt-get install -y mini-httpd incus-base

# 5) Nasadenie systemd servisu pre mini_httpd
cp install/mini_httpd.service /etc/systemd/system/mini_httpd.service
systemctl daemon-reload
systemctl enable mini_httpd
systemctl start mini_httpd

# 6) Vytvorenie webroot a CGI adresára
mkdir -p /var/www/incusko/cgi-bin

# 7) Kopírovanie frontendu (*.html, *.js)
cp -a ./*.html ./*.js /var/www/incusko/

# 8) Kopírovanie CGI skriptov
cp -a ./cgi-bin/* /var/www/incusko/cgi-bin/
chmod +x /var/www/incusko/cgi-bin/*.sh

# Nastavenie vlastníka www-data
chown -R www-data:www-data /var/www/incusko

echo "Inštalácia dokončená."
