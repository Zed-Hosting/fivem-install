# 🚀 FiveM FXServer Auto-Installer (Debian 12 / Ubuntu 22.04)

This script automates the full setup of a [FiveM FXServer](https://fivem.net/) game server on a fresh **Debian 12** or **Ubuntu 22.04** Linux system. It installs dependencies, downloads artifacts, sets up PM2 process manager, configures MariaDB (optional), and launches the server—**all with guided user prompts** and sensible defaults.

---

## 📦 What This Script Does

✅ Prompts user to customize:
- System username
- Install directories
- License key
- Database settings
- Hostname and player count

✅ Installs required packages:
- `curl`, `wget`, `git`, `mariadb-server`, `npm`, etc.

✅ Sets up:
- FXServer artifacts
- `cfx-server-data` repo
- `server.cfg` with values you choose
- PM2 to auto-start and manage the server
- Optional local MariaDB database

✅ Provides one-liner install support (e.g. `bash <(curl -sSL ...)`)

---

## 🚀 How to Run the Script

### 🧪 One-Line Command

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Zed-Hosting/fivem-install/refs/heads/main/install.sh)
```

## How to Update
```bash
cd /home/fivem/fx-server
wget -q https://zedhosting.gg/downloads/fivem_update.sh
bash fivem_update.sh

# Restart with PM2
pm2 restart fivem
pm2 save
```

