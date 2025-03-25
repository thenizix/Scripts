#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    1_system_setup.sh                                 :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg

# Funzione per verificare la connessione internet
check_internet() {
    echo -e "\033[1;33m🔍 Verifica connessione internet...\033[0m"
    if ! ping -c 1 -W 3 google.com &>/dev/null; then
        echo -e "\033[0;31m❌ Connessione internet assente! Controllare la rete\033[0m"
        exit 1
    fi
    echo -e "\033[0;32m✔ Connessione internet verificata\033[0m"
}

# Pulizia selettiva delle installazioni precedenti
clean_previous() {
    echo -e "\033[1;33m🧹 Pulizia installazioni precedenti...\033[0m"
    
    # Arresto servizi specifici
    systemctl stop nginx mariadb php${PHP_VERSION}-fpm 2>/dev/null
    
    # Rimozione mirata dei pacchetti
    apt purge -y nginx mariadb-server php${PHP_VERSION}-fpm \
       php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd \
       php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip \
       php${PHP_VERSION}-opcache php${PHP_VERSION}-intl --allow-remove-essential
    
    # Pulizia controllata delle directory
    rm -rf /var/www/html/* /etc/nginx/ssl /etc/nginx/sites-available/wordpress
    
    # Ripristino permessi di base
    find /var/www/ -type d -exec chmod 755 {} \;
    find /var/www/ -type f -exec chmod 644 {} \;
}

# Verifica presenza dipendenze critiche
check_dependencies() {
    local required=("wget" "tar" "systemctl" "openssl")
    local missing=()
    
    for cmd in "${required[@]}"; do
        if ! command -v $cmd &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "\033[0;31m❌ Componenti mancanti: ${missing[*]}\033[0m"
        apt update && apt install -y "${missing[@]}" || exit 1
    fi
}

# Ottimizzazione configurazione Nginx
optimize_nginx() {
    echo -e "\033[1;33m⚡ Ottimizzazione Nginx...\033[0m"
    
    local nginx_conf="/etc/nginx/nginx.conf"
    cp "$nginx_conf" "${nginx_conf}.bak"
    
    # Impostazioni ottimizzate
    sed -i "s/^worker_processes.*/worker_processes ${NGINX_WORKER_PROCESSES};/" "$nginx_conf"
    sed -i "s/^worker_connections.*/worker_connections ${NGINX_WORKER_CONNECTIONS};/" "$nginx_conf"
    sed -i "s/^keepalive_timeout.*/keepalive_timeout ${NGINX_KEEPALIVE_TIMEOUT};/" "$nginx_conf"
    sed -i "s/^client_max_body_size.*/client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};/" "$nginx_conf"
    
    # Verifica configurazione
    if ! nginx -t; then
        echo -e "\033[0;31m❌ Configurazione Nginx non valida! Ripristino backup...\033[0m"
        mv "${nginx_conf}.bak" "$nginx_conf"
        exit 1
    fi
}

# Main installation
echo -e "\033[1;36m🚀 Inizio installazione sistema base...\033[0m"
validate_config
check_dependencies
check_internet
clean_previous

echo -e "\033[1;33m🔄 Aggiornamento pacchetti...\033[0m"
apt update && apt upgrade -y

echo -e "\033[1;33m📦 Installazione pacchetti principali...\033[0m"
apt install -y \
    nginx \
    mariadb-server \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-intl

optimize_nginx

echo -e "\033[1;33m⚙️ Abilitazione servizi...\033[0m"
systemctl enable --now nginx mariadb php${PHP_VERSION}-fpm

echo -e "\033[0;32m✅ Sistema base installato correttamente\033[0m"