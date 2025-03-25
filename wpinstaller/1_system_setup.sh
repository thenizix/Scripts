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
# ****************************************************************************** #
#                                                                                #
#             INSTALLAZIONE BASE DEL SISTEMA (Nginx/PHP/MySQL) - WSL/Win         #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Funzione per verificare e configurare la connessione internet
check_internet() {
    echo -e "\033[1;33m🔍 Verifica connessione internet...\033[0m"
    local dns_servers=("8.8.8.8" "1.1.1.1" "9.9.9.9")
    local connected=0

    for dns in "${dns_servers[@]}"; do
        if ping -c 1 -W 3 "$dns" &>/dev/null; then
            echo -e "\033[0;32m✔ Connesso a $dns\033[0m"
            connected=1
            break
        fi
    done

    if [ "$connected" -eq 0 ]; then
        echo -e "\033[0;31m❌ Nessuna connessione rilevata\033[0m"
        echo -e "\033[1;33m⚠️  Configuro DNS temporanei...\033[0m"
        
        # Backup del file resolv.conf esistente
        cp /etc/resolv.conf /etc/resolv.conf.bak
        
        # Configurazione DNS di fallback
        for dns in "${dns_servers[@]}"; do
            echo "nameserver $dns" >> /etc/resolv.conf
        done
        
        # Verifica nuovamente
        if ! ping -c 1 google.com &>/dev/null; then
            echo -e "\033[0;31m❌ Impossibile stabilire connessione\033[0m"
            exit 1
        fi
    fi
}

# Funzione per pulire installazioni precedenti
clean_previous() {
    echo -e "\033[1;33m🧹 Pulizia installazioni precedenti...\033[0m"
    
    # Arresto servizi se attivi
    systemctl stop nginx mariadb php${PHP_VERSION}-fpm 2>/dev/null
    
    # Rimozione pacchetti
    apt purge -y nginx* php* mariadb* --allow-remove-essential
    
    # Pulizia directory
    rm -rf /var/www/html/* /etc/nginx/ssl /etc/nginx/sites-available/wordpress
    
    # Reimpostazione permessi
    find /var/www/ -type d -exec chmod 755 {} \;
    find /var/www/ -type f -exec chmod 644 {} \;
}

# Funzione per ottimizzare Nginx
optimize_nginx() {
    echo -e "\033[1;33m⚡ Ottimizzazione Nginx...\033[0m"
    
    # Backup configurazione originale
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    
    # Configurazione ottimizzata
    cat > /etc/nginx/nginx.conf <<EOF
user ${NGINX_USER};
worker_processes ${NGINX_WORKER_PROCESSES};

events {
    worker_connections ${NGINX_WORKER_CONNECTIONS};
    multi_accept on;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    
    keepalive_timeout ${NGINX_KEEPALIVE_TIMEOUT};
    keepalive_requests 1000;
    
    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_min_length 1000;
    gzip_proxied any;
    
    include /etc/nginx/sites-enabled/*;
}
EOF
}

# Main installation
echo -e "\033[1;36m🚀 Inizio installazione sistema base...\033[0m"
validate_config
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