#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    3_wordpress_setup.sh                               :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Controllo errori migliorato per download WordPress
install_wp() {
    echo -e "\033[1;33m📥 Download WordPress...\033[0m"
    
    # Verifica spazio disco
    if ! df --output=avail / | tail -1 | grep -E '^[0-9]{6}'; then
        echo -e "\033[0;31m❌ Spazio disco insufficiente!\033[0m"
        exit 1
    fi
    
    # Download con controllo integrità
    if ! wget -q https://wordpress.org/latest.tar.gz -P /tmp; then
        echo -e "\033[0;31m❌ Download fallito! Verificare:\033[0m"
        echo -e "1. Connessione internet"
        echo -e "2. Accesso a wordpress.org"
        exit 1
    fi
    
    # Estrazione con verifica
    if ! tar -tzf /tmp/latest.tar.gz >/dev/null; then
        echo -e "\033[0;31m❌ Archivio corrotto! Ricaricare...\033[0m"
        rm -f /tmp/latest.tar.gz
        exit 1
    fi
    
    tar -xzf /tmp/latest.tar.gz -C /var/www/html || {
        echo -e "\033[0;31m❌ Estrazione fallita! Permessi insufficienti?\033[0m"
        exit 1
    }
    
    # Gestione directory con fallback
    local wp_temp="/var/www/html/wordpress"
    if [ -d "$wp_temp" ]; then
        if [ "$wp_temp" != "${WP_DIR}" ]; then
            mv "$wp_temp" "${WP_DIR}" || {
                echo -e "\033[0;31m❌ Spostamento fallito! Verificare:\033[0m"
                echo -e "1. Spazio su disco"
                echo -e "2. Permessi directory"
                exit 1
            }
        fi
    else
        echo -e "\033[0;31m❌ Directory WordPress non trovata!\033[0m"
        exit 1
    fi
    
    rm -f /tmp/latest.tar.gz
}

# Configurazione Nginx con validazione
configure_nginx() {
    echo -e "\033[1;33m⚙️ Configurazione Nginx...\033[0m"
    
    # Template configurazione
    local nginx_conf="/etc/nginx/sites-available/wordpress"
    cp "$nginx_conf" "${nginx_conf}.bak" 2>/dev/null
    
    cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${WP_DIR};

    index index.php;

    access_log /var/log/nginx/wordpress.access.log;
    error_log /var/log/nginx/wordpress.error.log;

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

    # Validazione configurazione
    if ! nginx -t; then
        echo -e "\033[0;31m❌ Configurazione Nginx non valida! Ripristino backup...\033[0m"
        mv "${nginx_conf}.bak" "$nginx_conf"
        exit 1
    fi
    
    systemctl reload nginx
}

echo -e "\033[1;36m🚀 Installazione WordPress...\033[0m"
validate_config
install_wp
set_permissions
configure_nginx

echo -e "\033[0;32m✅ WordPress installato correttamente\033[0m"