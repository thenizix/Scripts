#!/bin/bash
# INSTALLAZIONE WORDPRESS - GESTIONE PERMESSI E CREDENZIALI

set -euo pipefail
trap 'echo "❌ Errore a linea $LINENO"; exit 1' ERR

# Caricamento configurazione
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/wp_install.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# Funzione: Verifica permessi directory
check_directory_perms() {
    local dir="$1"
    local expected_uid="$2"
    local expected_gid="$3"
    
    local actual_uid=$(stat -c '%u' "$dir")
    local actual_gid=$(stat -c '%g' "$dir")
    
    if [ "$actual_uid" != "$expected_uid" ] || [ "$actual_gid" != "$expected_gid" ]; then
        echo "❌ Permessi errati per $dir (atteso: ${expected_uid}:${expected_gid}, trovato: ${actual_uid}:${actual_gid})" | tee -a "$LOG_FILE"
        return 1
    fi
    return 0
}

# Main Process
{
    echo "=== INSTALLAZIONE WORDPRESS ===" | tee -a "$LOG_FILE"
    
    # 1. Preparazione ambiente
    echo "🗂️ Preparazione directory ${WP_DIR}..." | tee -a "$LOG_FILE"
    sudo rm -rf "${WP_DIR}"
    sudo mkdir -p "${WP_DIR}"
    sudo chown -R ${WP_UID}:${WP_GID} "${WP_DIR}"
    sudo chmod ${DIR_PERMS} "${WP_DIR}"
    
    # Verifica permessi
    check_directory_perms "${WP_DIR}" "$(id -u ${WP_UID})" "$(id -g ${WP_GID})" || exit 1

    # 2. Installazione WP-CLI
    echo "📥 Installazione WP-CLI..." | tee -a "$LOG_FILE"
    sudo curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    sudo chmod +x /usr/local/bin/wp
    sudo chown root:root /usr/local/bin/wp

    # 3. Download WordPress
    echo "⬇️ Download WordPress..." | tee -a "$LOG_FILE"
    sudo -u ${WP_UID} wp core download \
        --locale=it_IT \
        --path="${WP_DIR}" \
        --force

    # 4. Configurazione wp-config.php
    echo "🔧 Creazione wp-config.php..." | tee -a "$LOG_FILE"
    sudo -u ${WP_UID} wp config create \
        --dbname="${MYSQL_WP_DB}" \
        --dbuser="${MYSQL_WP_USER}" \
        --dbpass="${MYSQL_WP_PASS}" \
        --path="${WP_DIR}" \
        --extra-php <<PHP
define('FS_METHOD', 'direct');
define('WP_AUTO_UPDATE_CORE', false);
PHP

    # 5. Installazione WordPress
    ADMIN_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=')
    echo "🚀 Installazione WordPress..." | tee -a "$LOG_FILE"
    sudo -u ${WP_UID} wp core install \
        --url="${DOMAIN}" \
        --title="Sito WordPress" \
        --admin_user="admin" \
        --admin_password="${ADMIN_PASS}" \
        --admin_email="${ADMIN_EMAIL}" \
        --path="${WP_DIR}"

    # 6. Hardening sicurezza
    echo "🛡️ Applicazione misure di sicurezza..." | tee -a "$LOG_FILE"
    sudo find "${WP_DIR}" -type d -exec chmod ${DIR_PERMS} {} \;
    sudo find "${WP_DIR}" -type f -exec chmod ${FILE_PERMS} {} \;
    sudo chmod 600 "${WP_DIR}/wp-config.php"
    sudo chown ${WP_UID}:${WP_GID} "${WP_DIR}/wp-config.php"

    # 7. Configurazione aggiuntiva
    sudo -u ${WP_UID} wp config set DISALLOW_FILE_EDIT true --raw --path="${WP_DIR}"
    sudo -u ${WP_UID} wp config set WP_DEBUG ${WP_DEBUG} --raw --path="${WP_DIR}"

    echo "✅ WordPress installato correttamente!" | tee -a "$LOG_FILE"
    echo "   URL Admin: http://${DOMAIN}/wp-admin" | tee -a "$LOG_FILE"
    echo "   Username: admin" | tee -a "$LOG_FILE"
    echo "   Password: ${ADMIN_PASS}" | tee -a "$LOG_FILE"
}