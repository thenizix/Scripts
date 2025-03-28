#!/bin/bash

# ==============================================
# WordPress MySQL Setup Script
# Version: 2.0 (Fixed and Secure)
# ==============================================

set -euo pipefail
trap 'echo "Error at line $LINENO"; exit 1' ERR

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/mysql_setup.log"
MYSQL_WP_DB="wordpress"  # Default database name

# Initialize logging
mkdir -p "${SCRIPT_DIR}/../logs"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=== DATABASE SETUP STARTED ==="
echo "🕒 Timestamp: $(date)"

# --- Load Configuration ---
source "${CONFIG_FILE}"

# Verify required variables
declare -a REQUIRED_VARS=("MYSQL_ROOT_PASS" "MYSQL_WP_PASS")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: Missing $var in config"
        exit 1
    fi
done

# --- Database Functions ---
start_mysql() {
    echo "🔧 Starting MySQL service..."
    for attempt in {1..3}; do
        if sudo service mysql start; then
            if mysqladmin ping -uroot --silent; then
                return 0
            fi
        fi
        sleep 2
    done
    echo "❌ Failed to start MySQL"
    return 1
}

secure_installation() {
    echo "🔐 Securing MariaDB installation..."
    sudo mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE IF NOT EXISTS ${MYSQL_WP_DB};
CREATE USER IF NOT EXISTS 'wordpress'@'localhost' IDENTIFIED BY '${MYSQL_WP_PASS}';
GRANT ALL PRIVILEGES ON ${MYSQL_WP_DB}.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
EOF
}

# --- Main Execution ---
if start_mysql; then
    if mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "SELECT 1" >/dev/null 2>&1; then
        echo "ℹ️ MySQL already secured"
    else
        secure_installation
    fi

    # Verify database access
    if mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "USE ${MYSQL_WP_DB}" >/dev/null 2>&1; then
        echo "ℹ️ Database ${MYSQL_WP_DB} already exists"
    else
        echo "💽 Creating database ${MYSQL_WP_DB}"
        mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE ${MYSQL_WP_DB};
EOF
    fi
fi

echo "✅ Database setup completed successfully!"
echo "=== DATABASE SETUP FINISHED ==="
exit 0