#!/usr/bin/env bash
#
# provision-ec2.sh
# -----------------------------------------------------------------------------
# Provisions a fresh AWS EC2 Ubuntu 26.04 LTS instance with everything the
# LTI backend (Express + TypeScript + Prisma + PM2 + PostgreSQL) needs to
# build and run.
#
# Run ONCE on a clean instance as the `ubuntu` user (has sudo).
# The script is idempotent: re-running it will not fail on already-installed
# packages or an existing database/user.
#
# Usage:
#   chmod +x provision-ec2.sh
#   ./provision-ec2.sh                 # core stack only
#   INSTALL_NGINX=true ./provision-ec2.sh   # also install Nginx reverse proxy
# -----------------------------------------------------------------------------
set -euo pipefail

# =============================================================================
# Configuration — override via environment variables before running.
# CHANGE THE DEFAULT PASSWORD before using this anywhere real.
# These must match the backend's DATABASE_URL / schema.prisma connection.
# =============================================================================
DB_NAME="${DB_NAME:-LTIdb}"
DB_USER="${DB_USER:-LTIdbUser}"
DB_PASSWORD="${DB_PASSWORD:-CHANGE_ME_D1ymf8wyQEGthFR1E9xhCq}"

NODE_MAJOR="${NODE_MAJOR:-18}"      # Node.js LTS major version
APP_PORT="${APP_PORT:-3010}"        # port the backend listens on (see backend/src/index.ts)
INSTALL_NGINX="${INSTALL_NGINX:-false}"  # set to "true" to install Nginx as reverse proxy

if [[ "${DB_PASSWORD}" == CHANGE_ME_* ]]; then
  echo "WARNING: using the default DB_PASSWORD. Set DB_PASSWORD env var to a real secret." >&2
fi

# Helper: log a section header.
section() { echo; echo "==> $1"; }

# =============================================================================
# 1. System base packages
# =============================================================================
section "Updating apt and installing base tooling"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y \
  git \
  curl \
  ca-certificates \
  gnupg \
  build-essential \
  ufw

# =============================================================================
# 2. Node.js (LTS) + npm via NodeSource
# =============================================================================
section "Installing Node.js ${NODE_MAJOR}.x"
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v)" != v${NODE_MAJOR}.* ]]; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "Node.js $(node -v) already installed, skipping."
fi

# =============================================================================
# 3. PM2 (global) + boot startup
# =============================================================================
section "Installing PM2 and enabling startup on boot"
if ! command -v pm2 >/dev/null 2>&1; then
  sudo npm install -g pm2
else
  echo "PM2 $(pm2 -v) already installed, skipping."
fi
# Configure PM2 to relaunch saved processes after a reboot (runs as the ubuntu user).
sudo env PATH="$PATH:/usr/bin" pm2 startup systemd -u "$USER" --hp "$HOME"

# =============================================================================
# 4. PostgreSQL server + client, database and app user
# =============================================================================
section "Installing and configuring PostgreSQL"
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create the application role if it does not already exist (idempotent).
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER \"${DB_USER}\" WITH PASSWORD '${DB_PASSWORD}';"

# Keep the password in sync in case the role already existed.
sudo -u postgres psql -c "ALTER USER \"${DB_USER}\" WITH PASSWORD '${DB_PASSWORD}';"

# Create the application database owned by the app user if it does not exist.
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";"

# Ensure the app user can fully manage its database.
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";"

echo "PostgreSQL ready. DATABASE_URL for the backend .env should be:"
echo "  postgresql://${DB_USER}:<password>@localhost:5432/${DB_NAME}"

# =============================================================================
# 5. Nginx reverse proxy (optional)
# =============================================================================
if [[ "${INSTALL_NGINX}" == "true" ]]; then
  section "Installing and configuring Nginx reverse proxy"
  sudo apt-get install -y nginx
  sudo tee /etc/nginx/sites-available/lti-backend >/dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
  sudo ln -sf /etc/nginx/sites-available/lti-backend /etc/nginx/sites-enabled/lti-backend
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo nginx -t
  sudo systemctl enable nginx
  sudo systemctl restart nginx
else
  echo "Skipping Nginx (set INSTALL_NGINX=true to enable)."
fi

# =============================================================================
# 6. Firewall (ufw)
# =============================================================================
section "Configuring firewall (ufw)"
sudo ufw allow OpenSSH
if [[ "${INSTALL_NGINX}" == "true" ]]; then
  sudo ufw allow 'Nginx HTTP'    # port 80, traffic reaches the app via the proxy
else
  sudo ufw allow "${APP_PORT}/tcp"  # expose the backend port directly
fi
# Enable non-interactively (|| true so a re-run that's already enabled won't fail).
sudo ufw --force enable

# =============================================================================
# 7. Summary
# =============================================================================
section "Provisioning complete — installed versions:"
echo "  node : $(node -v)"
echo "  npm  : $(npm -v)"
echo "  pm2  : $(pm2 -v)"
echo "  psql : $(psql --version)"
if [[ "${INSTALL_NGINX}" == "true" ]]; then
  echo "  nginx: $(nginx -v 2>&1)"
fi
echo
echo "Next steps:"
echo "  1. Clone the repo and create backend/.env with the DATABASE_URL above."
echo "  2. Run the GitHub Actions deploy job (or deploy manually with PM2)."
