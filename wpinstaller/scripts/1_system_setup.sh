#!/bin/bash
# wpinstaller/scripts/1_system_setup.sh
# CONFIGURAZIONE SISTEMA - INSTALLAZIONE PACCHETTI NECESSARI

set -euo pipefail
trap 'echo "Errore a linea $LINENO"; exit 1' ERR

# Caricamento configurazione
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/system_setup.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# Funzioni
update_system() {
    echo "🔄 Aggiornamento repository..." | tee -a "$LOG_FILE"
    apt-get update
    apt-get upgrade -y
}

install_packages() {
    echo "📦 Installazione pacchetti necessari..." | tee -a "$LOG_FILE"
    apt-get install -y \
        nginx \
        mariadb-server \
        php${PHP_VERSION} \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
        curl \
        wget \
        unzip \
        openssl
}

configure_nginx() {
    echo "🔧 Configurazione Nginx..." | tee -a "$LOG_FILE"
    
    # Seleziona template appropriato
    local template
    if [ "${ENV_MODE}" = "prod" ]; then
        template="${SCRIPT_DIR}/../templates/nginx-prod.conf"
    else
        template="${SCRIPT_DIR}/../templates/nginx-local.conf"
    fi
    
    # Applica sostituzioni
    local config_content
    config_content=$(cat "$template" | sed \
        -e "s|{{SERVER_PORT}}|${SERVER_PORT}|g" \
        -e "s|{{DOMAIN}}|${DOMAIN}|g" \
        -e "s|{{WP_DIR}}|${WP_DIR}|g" \
        -e "s|{{PHP_VERSION}}|${PHP_VERSION}|g")
    
    # Salva configurazione
    echo "$config_content" > "/etc/nginx/sites-available/wordpress"
    
    # Attiva configurazione
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        rm /etc/nginx/sites-enabled/default
    fi
    
    if [ ! -L "/etc/nginx/sites-enabled/wordpress" ]; then
        ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
    fi
}

configure_php() {
    echo "🔧 Configurazione PHP..." | tee -a "$LOG_FILE"
    
    # Aumenta limiti
    sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/${PHP_VERSION}/fpm/php.ini
    
    # Disabilita funzioni pericolose
    sed -i 's/;?disable_functions =.*/disable_functions = exec,passthru,shell_exec,system,proc_open,popen,parse_ini_file,show_source/' /etc/php/${PHP_VERSION}/fpm/php.ini
}

restart_services() {
    echo "🔄 Riavvio servizi..." | tee -a "$LOG_FILE"
    
    ${SERVICE_CMD} php${PHP_VERSION}-fpm restart
    ${SERVICE_CMD} nginx restart
}

# Main process
{
    echo "=== CONFIGURAZIONE SISTEMA ===" | tee -a "$LOG_FILE"
    
    update_system
    install_packages
    configure_nginx
    configure_php
    restart_services
    
    echo "✅ Configurazione sistema completata!" | tee -a "$LOG_FILE"
}