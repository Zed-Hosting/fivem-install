#!/usr/bin/env bash
set -euo pipefail

# --- Prompt with default helper ---
prompt() {
  local var_name=$1
  local prompt_msg=$2
  local default_val=$3
  read -rp "$prompt_msg [$default_val]: " input
  eval "$var_name=\"\${input:-$default_val}\""
}

echo "==== FiveM Auto-Install Script for Debian 12 / Ubuntu 22.04 ===="
echo "Press ENTER to accept defaults or type to override."

# --- Collect user input ---
prompt FIVEM_USER "Enter system username to run FiveM" "fivem"
prompt FIVEM_BASE "FXServer install directory" "/home/${FIVEM_USER}/fx-server"
prompt FIVEM_DATA "FXServer data directory" "/home/${FIVEM_USER}/fx-server-data"
prompt LICENSE_KEY "Enter your FiveM license key" "changeme"
prompt DB_USER "MariaDB username" "fivem"
prompt DB_PASS "MariaDB password" "changeme"
prompt DB_NAME "MariaDB database name" "fivem_db"
prompt HOSTNAME "Server hostname" "Zed Hosting FXServer"
prompt MAXCLIENTS "Max player count" "10"

echo "Installing dependencies..."
apt update && apt install -y curl wget jq npm nano git git-lfs mariadb-server

echo "Creating system user '$FIVEM_USER'..."
id -u "$FIVEM_USER" &>/dev/null || adduser --disabled-password --gecos "" "$FIVEM_USER"

echo "Creating directories..."
mkdir -p "$FIVEM_BASE" "$FIVEM_DATA"
chown -R "$FIVEM_USER:$FIVEM_USER" "$(dirname "$FIVEM_BASE")"

echo "Installing FXServer..."
cd "$FIVEM_BASE"
sudo -u "$FIVEM_USER" wget -q https://zedhosting.gg/downloads/fivem_install.sh
sudo -u "$FIVEM_USER" bash fivem_install.sh

echo "Cloning cfx-server-data..."
cd "$FIVEM_DATA"
sudo -u "$FIVEM_USER" git clone https://github.com/citizenfx/cfx-server-data .

echo "Creating server.cfg..."
sudo -u "$FIVEM_USER" tee "$FIVEM_DATA/server.cfg" > /dev/null <<EOF
endpoint_add_tcp "0.0.0.0:30120"
endpoint_add_udp "0.0.0.0:30120"

ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap
ensure rconlog

sv_scriptHookAllowed 0
sets tags "default"
sets locale "en-US"

sv_hostname "${HOSTNAME}"
sets sv_projectName "${HOSTNAME}"
sets sv_projectDesc "FXServer setup via script"

set temp_convar "ZED"
set onesync on
sv_maxclients ${MAXCLIENTS}

set steam_webApiKey ""
sv_licenseKey "${LICENSE_KEY}"
EOF

echo "Configuring MariaDB..."
systemctl enable --now mariadb
mysql -uroot <<MYSQL
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
MYSQL

echo "Installing PM2..."
npm install -g pm2

echo "Fetching run/start scripts..."
cd "$FIVEM_BASE"
sudo -u "$FIVEM_USER" wget -q https://zedhosting.gg/downloads/fivem_start.sh
sudo -u "$FIVEM_USER" wget -q https://zedhosting.gg/downloads/run.sh

echo "Launching server with PM2..."
sudo -u "$FIVEM_USER" pm2 start fivem_start.sh --name fivem
sudo -u "$FIVEM_USER" pm2 startup
sudo -u "$FIVEM_USER" pm2 save

echo "✅ Installation complete!"
echo "You can now run:"
echo "  pm2 logs fivem       # to view logs"
echo "  pm2 restart fivem    # to restart server"
echo "  nano ${FIVEM_DATA}/server.cfg  # to edit config"

# Get public IP address
SERVER_IP=$(curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
FIVEM_URL="http://${SERVER_IP}:40120"

echo ""
echo "🌐 Your FiveM server web interface may be available at:"
echo "👉 ${FIVEM_URL}"
echo ""

# Try to open it if GUI browser available
if command -v xdg-open &>/dev/null; then
  xdg-open "${FIVEM_URL}" &>/dev/null &
elif command -v gnome-open &>/dev/null; then
  gnome-open "${FIVEM_URL}" &>/dev/null &
elif command -v open &>/dev/null; then
  open "${FIVEM_URL}" &>/dev/null &
fi

