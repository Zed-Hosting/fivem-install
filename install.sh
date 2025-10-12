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

RESTORE='\033[0m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
LIGHTGRAY='\033[00;37m'
LRED='\033[01;31m'
LGREEN='\033[01;32m'
LYELLOW='\033[01;33m'
LBLUE='\033[01;34m'
LPURPLE='\033[01;35m'
LCYAN='\033[01;36m'
WHITE='\033[01;37m'

WARN=$'\033[01;31m'
RESET=$'\e[0m'
 
echo -e "${YELLOW}=======================${RESTORE}">>setup.log 2>>error.log
date >>setup.log 2>>error.log
echo -e "${YELLOW}=======================${RESTORE}">>setup.log 2>>error.log

echo -e "${LCYAN}==== FiveM Auto-Install Script for Debian 12 / Ubuntu 22.04 ====${RESTORE}"
echo -e "${LCYAN}Press ENTER to accept defaults or type to override${RESTORE}"

# --- Collect user input ---
echo -e "${LBLUE}"
prompt FIVEM_USER "Enter system username to run FiveM (optional)" "fivem"
prompt FIVEM_BASE "FXServer install directory (optional)" "/home/${FIVEM_USER}/fx-server"
prompt FIVEM_DATA "FXServer data directory (optional)" "/home/${FIVEM_USER}/fx-server-data"
#prompt LICENSE_KEY "${RED}Enter your FiveM license key (REQUIRED)${RESTORE}" "changeme"

echo -e "${LRED}"
LICENSE_KEY=""
while [ -z "$LICENSE_KEY" ]; do
    read -p "Enter your FiveM license key (REQUIRED)${RESET}: " LICENSE_KEY
    if [ -z "$LICENSE_KEY" ]; then
        echo -e "${YELLOW}License key cannot be empty. Please try again.${RESTORE}"
    fi
done
echo -e "${LBLUE}"
prompt DB_USER "MariaDB username (optional)" "fivem"
prompt DB_PASS "MariaDB password (optional)" "fivem123"
prompt DB_NAME "MariaDB database name (optional)" "fivem_db"
prompt HOSTNAME "Server hostname (optional)" "Zed Hosting FXServer"
prompt MAXCLIENTS "Max player count (optional)" "10"

echo -e "${LBLUE}Installing dependencies...${RESTORE}"
apt update >>setup.log 2>>error.log && apt install -y curl wget jq npm nano git git-lfs mariadb-server >>setup.log 2>>error.log

echo -e "${LBLUE}Creating system user '$FIVEM_USER'...${RESTORE}"
id -u "$FIVEM_USER" &>/dev/null || adduser --disabled-password --gecos "" "$FIVEM_USER" >>setup.log 2>>error.log

# Check if the directory exists
if [ -d "$FIVEM_DATA" ]; then
    read -p "Installation found. Do you want to remove it? (y/n): " choice
    case "$choice" in
        y|Y )
            echo -e "${LRED}Removing Old Installation...${RESTORE}"
            rm -rf "$FIVEM_DATA"
            rm -rf "$FIVEM_BASE"
            echo -e "${LYELLOW}Directories Removed${RESTORE}"
            sudo -u ${FIVEM_USER} pm2 delete fivem >>setup.log 2>>error.log
            echo -e "${LYELLOW}Old Deployment Removed${RESTORE}"
            echo -e "${LBLUE}Creating New Directories...${RESTORE}"
            mkdir -p "$FIVEM_BASE" "$FIVEM_DATA" >>setup.log 2>>error.log
            chown -R "$FIVEM_USER:$FIVEM_USER" "$(dirname "$FIVEM_BASE")" >>setup.log 2>>error.log
            ;;
        n|N )
            echo "Operation cancelled. Directory '$FIVEM_DATA' will not be removed."
            exit 0 # Exit successfully after cancellation
            ;;
        * )
            echo "Invalid input. Operation cancelled."
            exit 1 # Exit with an error code for invalid input
            ;;
    esac
else
    #echo -e "${WHITE}Directory '$FIVEM_DATA' does not exist.${RESTORE}"
    echo -e "${LBLUE}Creating directories...${RESTORE}"
    mkdir -p "$FIVEM_BASE" "$FIVEM_DATA" >>setup.log 2>>error.log
    chown -R "$FIVEM_USER:$FIVEM_USER" "$(dirname "$FIVEM_BASE")" >>setup.log 2>>error.log
fi

echo -e "${LBLUE}Installing FXServer...${RESTORE}"
cd "$FIVEM_BASE"
sudo -u "$FIVEM_USER" wget -q https://zedhosting.gg/downloads/fivem_install.sh >>setup.log 2>>error.log
sudo -u "$FIVEM_USER" bash fivem_install.sh >>setup.log 2>>error.log

echo -e "${LBLUE}Cloning cfx-server-data...${RESTORE}"
cd "$FIVEM_DATA"
sudo -u "$FIVEM_USER" git clone --quiet https://github.com/citizenfx/cfx-server-data . 

echo -e "${LBLUE}Creating server.cfg...${RESTORE}"
sudo -u "$FIVEM_USER" tee "$FIVEM_DATA/server.cfg" > /dev/null <<EOF
endpoint_add_tcp "0.0.0.0:30120"
endpoint_add_udp "0.0.0.0:30120"

sv_scriptHookAllowed 0
sets tags "default"
sets locale "en-US"

sv_hostname "${HOSTNAME}"
sets sv_projectName "${HOSTNAME}"
sets sv_projectDesc "FXServer setup via script"

#Database Info
#set mysql_debug true
#set mysql_ui true
set mysql_slow_query_warning 1200
set mysql_connection_string "mysql://${DB_USER}:${DB_PASS}@localhost:3306/${DB_NAME}?waitForConnections=true&charset=utf8mb4"

set temp_convar "ZED"
set onesync on
sv_maxclients ${MAXCLIENTS}

# Loading a server icon (96x96 PNG file)
load_server_icon myLogo.png

set steam_webApiKey ""
sv_licenseKey "${LICENSE_KEY}"

#Security precautions
set sv_requestParanoia 3
sv_endpointprivacy true
sv_authMinTrust 4
set sv_kick_players_cnl 0
set rateLimiter_stateBag_rate 100
set rateLimiter_stateBag_burst 150

increase_pool_size "AnimStore" 20480
increase_pool_size "TxdStore" 20480

set mumble_voice_prerelease 0

# Seatbelt natives
setr game_enableFlyThroughWindscreen true
setr game_enablePlayerRagdollOnCollision true

# Voice config
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
setr voice_defaultCycle "GRAVE"
setr voice_defaultVolume 0.3
setr voice_enableRadioAnim 1
setr voice_syncData 1

ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap
ensure rconlog
EOF

echo -e "${LBLUE}Configuring MariaDB...${RESTORE}"
systemctl enable --now mariadb >>setup.log 2>>error.log
mysql -uroot <<MYSQL
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
MYSQL

echo -e "${LBLUE}Installing PM2...${RESTORE}"
npm install -g pm2 >>setup.log 2>>error.log

echo -e "${LBLUE}Fetching run/start scripts...${RESTORE}"
cd "$FIVEM_BASE"
sudo -u "$FIVEM_USER" wget -q https://zedhosting.gg/downloads/fivem_start.sh >>setup.log 2>>error.log
sudo -u "$FIVEM_USER" wget -q https://zedhosting.gg/downloads/run.sh >>setup.log 2>>error.log

echo -e "${LBLUE}Launching server with PM2...${RESTORE}"
sudo -u "$FIVEM_USER" pm2 start fivem_start.sh --name fivem >>setup.log 2>>error.log
sudo env PATH=$PATH:/usr/bin /usr/local/lib/node_modules/pm2/bin/pm2 startup systemd -u "$FIVEM_USER" --hp /home/fivem >>setup.log 2>>error.log
sudo -u "$FIVEM_USER" pm2 save >>setup.log 2>>error.log

sudo -u "$FIVEM_USER" pm2 stop fivem >>setup.log 2>>error.log
sudo -u "$FIVEM_USER" mkdir -p "$FIVEM_BASE/txData/default/"
sudo -u "$FIVEM_USER" tee "$FIVEM_BASE/txData/default/config.json" > /dev/null <<EOF
{
  "version": 2,
  "server": {
    "dataPath": "${FIVEM_DATA}",
    "startupArgs": [
      "+set",
      "sv_enforceGameBuild",
      "3258"
    ]
  },
  "general": {
    "serverName": "${HOSTNAME}"
  },
  "banlist": {
    "enabled": false
  },
  "whitelist": {
    "mode": "approvedLicense"
  },
  "gameFeatures": {
    "hideAdminInMessages": true,
    "menuEnabled": false
  }
}
EOF
sudo -u "$FIVEM_USER" pm2 start fivem >>setup.log 2>>error.log
sleep 10
#sudo -u "$FIVEM_USER" pm2 restart fivem >>setup.log 2>>error.log
sudo -u "$FIVEM_USER" pm2 logs fivem --nostream --out --lines 30

echo ""
echo -e "✅ ${GREEN}Installation complete!${RESTORE}"
echo ""
echo -e "${WHITE}You can now run:"
echo -e "${WHITE} sudo -u "$FIVEM_USER" pm2 logs fivem       # to view logs"
echo -e "${WHITE} sudo -u "$FIVEM_USER" pm2 restart fivem    # to restart server"
echo -e "${WHITE} sudo -u "$FIVEM_USER" nano ${FIVEM_DATA}/server.cfg  # to edit config"

# Get public IP address
SERVER_IP=$(curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
FIVEM_URL="http://${SERVER_IP}:40120"

echo ""
echo -e "${WHITE}🌐 Your FiveM server web interface may be available at:${RESTORE}"
echo ""
echo -e "${GREEN}👉 ${FIVEM_URL} ${RESTORE}"
echo ""
echo -e "${WHITE}🔢 The PIN is listed above${RESTORE}"

# Try to open it if GUI browser available
if command -v xdg-open &>/dev/null; then
  xdg-open "${FIVEM_URL}" &>/dev/null &
elif command -v gnome-open &>/dev/null; then
  gnome-open "${FIVEM_URL}" &>/dev/null &
elif command -v open &>/dev/null; then
  open "${FIVEM_URL}" &>/dev/null &
fi

