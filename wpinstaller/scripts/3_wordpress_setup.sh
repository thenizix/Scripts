#!/bin/bash
# wpinstaller/scripts/3_wordpress_setup.sh
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

# Funzione: Verifica dipendenze
check_dependencies() {
    echo "🔍 Verifica dipendenze..." | tee -a "$LOG_FILE"
    
    # Verifica database
    if ! mysql -u "${MYSQL_WP_USER}" -p"${MYSQL_WP_PASS}" -e "SHOW TABLES FROM \`${MYSQL_WP_DB}\`;" &>/dev/null; then
        echo "❌ Connessione database fallita. Eseguire prima lo script di configurazione database." | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # Verifica Nginx
    if ! command -v nginx &>/dev/null || ! ${SERVICE_CMD} nginx status &>/dev/null; then
        echo "❌ Nginx non installato o non in esecuzione. Eseguire prima lo script di configurazione sistema." | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # Verifica PHP
    if ! command -v php &>/dev/null; then
        echo "❌ PHP non installato. Eseguire prima lo script di configurazione sistema." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Main Process
{
    echo "=== INSTALLAZIONE WORDPRESS ===" | tee -a "$LOG_FILE"
    
    # 1. Verifica dipendenze
    check_dependencies
    
    # 2. Preparazione directory
    echo "🗂️ Preparazione directory ${WP_DIR}..." | tee -a "$LOG_FILE"
    mkdir -p "${WP_DIR}"
    chown -R "${WP_UID}:${WP_GID}" "${WP_DIR}"
    chmod "${DIR_PERMS}" "${WP_DIR}"
    
    # Verifica permessi
    wp_uid_num=$(id -u "${WP_UID}")
    wp_gid_num=$(id -g "${WP_GID}")
    check_directory_perms "${WP_DIR}" "${wp_uid_num}" "${wp_gid_num}" || exit 1

    # 3. Installazione WP-CLI
    echo "📥 Installazione WP-CLI..." | tee -a "$LOG_FILE"
    if ! command -v wp &>/dev/null; then
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
    fi

    # 4. Download WordPress
    echo "⬇️ Download WordPress..." | tee -a "$LOG_FILE"
    cd "${WP_DIR}"
    if su -s /bin/bash "${WP_UID}" -c "wp core is-installed --path='${WP_DIR}'" 2>/dev/null; then
        echo "ℹ️ WordPress già installato, salto il download" | tee -a "$LOG_FILE"
    else
        su -s /bin/bash "${WP_UID}" -c "wp core download --locale=it_IT --path='${WP_DIR}'"
    fi

    # 5. Configurazione wp-config.php
    echo "🔧 Creazione wp-config.php..." | tee -a "$LOG_FILE"
    if [ ! -f "${WP_DIR}/wp-config.php" ]; then
        su -s /bin/bash "${WP_UID}" -c "wp config create \
            --dbname='${MYSQL_WP_DB}' \
            --dbuser='${MYSQL_WP_USER}' \
            --dbpass='${MYSQL_WP_PASS}' \
            --path='${WP_DIR}' \
            --extra-php <<PHP
define('FS_METHOD', 'direct');
define('WP_AUTO_UPDATE_CORE', false);
define('WP_DEBUG', ${WP_DEBUG});
define('DISALLOW_FILE_EDIT', true);
PHP"
    else
        echo "ℹ️ wp-config.php già esistente" | tee -a "$LOG_FILE"
    fi

    # 6. Installazione WordPress
    echo "🚀 Installazione WordPress..." | tee -a "$LOG_FILE"
    if su -s /bin/bash "${WP_UID}" -c "wp core is-installed --path='${WP_DIR}'" 2>/dev/null; then
        echo "ℹ️ WordPress già installato" | tee -a "$LOG_FILE"
        
        # Aggiorna admin password se necessario
        ADMIN_USER_EXISTS=$(su -s /bin/bash "${WP_UID}" -c "wp user get admin --path='${WP_DIR}' --field=login" 2>/dev/null || echo "")
        if [ -n "${ADMIN_USER_EXISTS}" ]; then
            ADMIN_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c 16)
            su -s /bin/bash "${WP_UID}" -c "wp user update admin --user_pass='${ADMIN_PASS}' --path='${WP_DIR}'"
            echo "ℹ️ Password admin aggiornata" | tee -a "$LOG_FILE"
        fi
    else
        ADMIN_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c 16)
        su -s /bin/bash "${WP_UID}" -c "wp core install \
            --url='${DOMAIN}' \
            --title='Sito WordPress' \
            --admin_user='admin' \
            --admin_password='${ADMIN_PASS}' \
            --admin_email='${ADMIN_EMAIL}' \
            --path='${WP_DIR}'"
    fi

    # 7. Hardening sicurezza
    echo "🛡️ Applicazione misure di sicurezza..." | tee -a "$LOG_FILE"
    find "${WP_DIR}" -type d -exec chmod "${DIR_PERMS}" {} \;
    find "${WP_DIR}" -type f -exec chmod "${FILE_PERMS}" {} \;
    chmod 600 "${WP_DIR}/wp-config.php"
    chown -R "${WP_UID}:${WP_GID}" "${WP_DIR}"

    # 8. Configurazione lingua italiana
    echo "🌍 Configurazione italiano..." | tee -a "$LOG_FILE"
    su -s /bin/bash "${WP_UID}" -c "wp language core install it_IT --path='${WP_DIR}' --activate"

    echo "✅ WordPress installato correttamente!" | tee -a "$LOG_FILE"
    echo "   URL Admin: http://${DOMAIN}/wp-admin" | tee -a "$LOG_FILE"
    echo "   Username: admin" | tee -a "$LOG_FILE"
    echo "   Password: ${ADMIN_PASS}" | tee -a "$LOG_FILE"
    
    # Salva credenziali in un file
    echo "WordPress admin login" > "${SCRIPT_DIR}/../logs/wp_credentials.txt"
    echo "URL: http://${DOMAIN}/wp-admin" >> "${SCRIPT_DIR}/../logs/wp_credentials.txt"
    echo "Username: admin" >> "${SCRIPT_DIR}/../logs/wp_credentials.txt"
    echo "Password: ${ADMIN_PASS}" >> "${SCRIPT_DIR}/../logs/wp_credentials.txt"
    chmod 600 "${SCRIPT_DIR}/../logs/wp_credentials.txt"
}