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

# Funzione per verificare e riparare pacchetti
check_repair_packages() {
    echo -e "\033[1;33m🛠️ Verifica e riparazione pacchetti...\033[0m"
    
    # Lista pacchetti necessari
    local required_packages=(
        nginx
        mariadb-server
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-mysql"
        "php${PHP_VERSION}-gd"
        "php${PHP_VERSION}-mbstring"
        "php${PHP_VERSION}-xml"
        "php${PHP_VERSION}-zip"
        "php${PHP_VERSION}-opcache"
        "php${PHP_VERSION}-intl"
    )
    
    # Verifica e installa solo ciò che manca
    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  ${pkg} "; then
            echo -e "\033[1;34m⬇️ Installazione ${pkg}...\033[0m"
            apt install -y "$pkg" || {
                echo -e "\033[0;31m❌ Installazione fallita per ${pkg}\033[0m"
                exit 1
            }
        else
            echo -e "\033[0;32m✔ ${pkg} già installato\033[0m"
            # Ripara il pacchetto se necessario
            apt install --reinstall -y "$pkg" >/dev/null 2>&1
        fi
    done
}

# Configurazione Nginx con template
configure_nginx() {
    echo -e "\033[1;33m🔧 Configurazione Nginx...\033[0m"
    
    local nginx_conf="/etc/nginx/nginx.conf"
    local nginx_site="/etc/nginx/sites-available/wordpress"
    
    # Backup configurazione esistente
    [ -f "$nginx_conf" ] && cp "$nginx_conf" "${nginx_conf}.bak"
    
    # Configurazione principale
    cat > "$nginx_conf" <<EOF
user ${NGINX_USER};
worker_processes ${NGINX_WORKER_PROCESSES};
pid /run/nginx.pid;

events {
    worker_connections ${NGINX_WORKER_CONNECTIONS};
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout ${NGINX_KEEPALIVE_TIMEOUT};
    types_hash_max_size 2048;
    client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    gzip on;
    gzip_disable "msie6";
    
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # Configurazione sito WordPress
    cat > "$nginx_site" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${WP_DIR};
    
    index index.php;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF

    # Abilita il sito
    ln -sf "$nginx_site" "/etc/nginx/sites-enabled/"
    
    # Test configurazione
    if ! nginx -t; then
        echo -e "\033[0;31m❌ Configurazione Nginx non valida!\033[0m"
        return 1
    fi
    
    systemctl restart nginx
}

# Main
echo -e "\033[1;36m🚀 Configurazione sistema base...\033[0m"

# Aggiornamento pacchetti
apt update && apt upgrade -y

# Verifica e installa pacchetti
check_repair_packages

# Configurazione Nginx
configure_nginx || exit 1

# Abilita servizi
systemctl enable --now nginx mariadb php${PHP_VERSION}-fpm

echo -e "\033[0;32m✅ Configurazione sistema completata\033[0m"