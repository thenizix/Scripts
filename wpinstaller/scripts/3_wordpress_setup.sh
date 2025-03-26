#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    3_wordpress_setup.sh                               :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.it          #
#                                                                                #
# ****************************************************************************** #

# Configurazioni
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"

# Caricamento configurazioni
source "${CONFIG_DIR}/wp_installer.cfg" || {
    echo -e "\033[0;31m❌ Errore nel caricamento della configurazione\033[0m" >&2
    exit 1
}

# Verifica permessi root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[0;31m❌ Lo script deve essere eseguito come root!\033[0m" >&2
    exit 1
fi

# Funzioni
install_wp() {
    echo -e "\033[1;34mDownload di WordPress...\033[0m"
    
    # Crea directory se non esiste
    mkdir -p "${WP_DIR}"
    
    # Download WordPress in italiano
    if ! wp core download --locale=it_IT --path="${WP_DIR}" --force; then
        echo -e "\033[0;31m❌ Errore nel download di WordPress\033[0m" >&2
        exit 1
    fi
    
    echo -e "\033[1;34mConfigurazione WordPress...\033[0m"
    
    # Crea file di configurazione
    if ! wp config create \
        --dbname="${MYSQL_WP_DB}" \
        --dbuser="${MYSQL_WP_USER}" \
        --dbpass="${MYSQL_WP_PASS}" \
        --path="${WP_DIR}"; then
        echo -e "\033[0;31m❌ Errore nella creazione della configurazione WordPress\033[0m" >&2
        exit 1
    fi
    
    # Installa WordPress
    local wp_url="http://${DOMAIN}"
    [ "$SERVER_PORT" != "80" ] && wp_url="${wp_url}:${SERVER_PORT}"
    
    if ! wp core install \
        --url="${wp_url}" \
        --title="Sito WordPress" \
        --admin_user="admin" \
        --admin_password="admin" \
        --admin_email="${ADMIN_EMAIL}" \
        --path="${WP_DIR}"; then
        echo -e "\033[0;31m❌ Errore nell'installazione di WordPress\033[0m" >&2
        exit 1
    fi
    
    # Configura debug
    if [ "$WP_DEBUG" = "true" ]; then
        wp config set WP_DEBUG true --raw --path="${WP_DIR}"
        wp config set WP_DEBUG_LOG true --raw --path="${WP_DIR}"
        wp config set WP_DEBUG_DISPLAY true --raw --path="${WP_DIR}"
    fi
}

secure_wp() {
    echo -e "\033[1;34mSicurezza installazione WordPress...\033[0m"
    
    # Imposta permessi corretti
    chown -R www-data:www-data "${WP_DIR}"
    find "${WP_DIR}" -type d -exec chmod 755 {} \;
    find "${WP_DIR}" -type f -exec chmod 644 {} \;
    
    # File di configurazione più restrittivi
    chmod 640 "${WP_DIR}/wp-config.php"
    
    # Disabilita l'editor di file
    wp config set DISALLOW_FILE_EDIT true --raw --path="${WP_DIR}"
    
    # Aggiorna WordPress
    wp core update --path="${WP_DIR}"
    wp core update-db --path="${WP_DIR}"
    
    # Rimuove file readme.html
    rm -f "${WP_DIR}/readme.html"
}

main() {
    echo -e "\033[1;36m=== Installazione WordPress ===\033[0m"
    
    # Verifica che MySQL sia attivo
    if ! systemctl is-active mariadb >/dev/null; then
        echo -e "\033[0;31m❌ MySQL/MariaDB non è attivo!\033[0m" >&2
        exit 1
    fi
    
    install_wp
    secure_wp
    
    echo -e "\033[0;32m✅ WordPress installato correttamente!\033[0m"
    echo -e "\033[1;33m⚠ Cambiare le credenziali di amministrazione dopo il primo accesso!\033[0m"
}

main