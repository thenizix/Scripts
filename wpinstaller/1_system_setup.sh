#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    1_system_setup.sh                                   :+:      :+:    :+:     #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Funzione migliorata per verificare la connessione internet
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
    
    # Rimozione mirata dei pacchetti (evitando wildcard pericolosi)
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


check_mariadb_installation() {
    if ! command -v mariadb &>/dev/null; then
        echo -e "\033[0;31m❌ MariaDB non installato correttamente!\033[0m"
        apt purge -y mariadb*
        apt install -y mariadb-server
    fi
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