#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    1_system_setup.sh                                  :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.it          #
#                                                                                #
# ****************************************************************************** #

# Carica configurazioni
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/wp_installer.cfg"

# ============================================================================== #
# FUNZIONI DI INSTALLAZIONE
# ============================================================================== #

install_packages() {
    echo -e "\033[1;34m\nInstallo pacchetti necessari...\033[0m"
    
    # Lista pacchetti base
    local packages=(
        "nginx"
        "mariadb-server"
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-mysql"
        "curl"
        "unzip"
        "openssl"
    )
    
    # Aggiunge Certbot solo se necessario
    if [ "$SSL_TYPE" = "letsencrypt" ]; then
        packages+=("certbot" "python3-certbot-nginx")
    fi
    
    # Installazione effettiva
    if ! apt-get update --fix-missing || ! apt-get install -y "${packages[@]}"; then
        echo -e "\033[0;31m❌ Installazione pacchetti fallita!\033[0m" >&2
        exit 1
    fi
}

configure_nginx() {
    echo -e "\033[1;34m\nConfiguro Nginx...\033[0m"
    
    # Percorsi file
    local template_file="${SCRIPT_DIR}/../templates/nginx-${ENV_MODE}.conf"
    local target_file="/etc/nginx/sites-available/wordpress"
    
    # Verifica template
    if [ ! -f "$template_file" ]; then
        echo -e "\033[0;31m❌ Template Nginx non trovato!\033[0m" >&2
        exit 1
    fi
    
    # Sostituisce placeholder nel template
    sed -e "s/{{DOMAIN}}/${DOMAIN}/g" \
       -e "s|{{WP_DIR}}|${WP_DIR}|g" \
       -e "s/{{PHP_VERSION}}/${PHP_VERSION}/g" \
       -e "s/{{SERVER_PORT}}/${SERVER_PORT}/g" \
       "$template_file" > "$target_file"
    
    # Abilita il sito
    ln -sf "$target_file" "/etc/nginx/sites-enabled/"
    
    # Riavvia Nginx
    if ! nginx -t || ! systemctl restart nginx; then
        echo -e "\033[0;31m❌ Errore configurazione Nginx!\033[0m" >&2
        exit 1
    fi
}

# ============================================================================== #
# MAIN
# ============================================================================== #

echo -e "\033[1;36m=== CONFIGURAZIONE SISTEMA ===\033[0m"

install_packages
configure_nginx

# Abilita servizi
systemctl enable nginx mariadb php${PHP_VERSION}-fpm
systemctl restart mariadb php${PHP_VERSION}-fpm

echo -e "\033[0;32m\n✅ Sistema configurato correttamente!\033[0m"