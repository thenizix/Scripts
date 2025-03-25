#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    3_wordpress_setup.sh                              :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg

# Funzione mancante per i permessi
set_permissions() {
    echo -e "\033[1;33m🔒 Impostazione permessi...\033[0m"
    chown -R www-data:www-data "${WP_DIR}"
    find "${WP_DIR}" -type d -exec chmod 750 {} \;
    find "${WP_DIR}" -type f -exec chmod 640 {} \;
    chmod 600 "${WP_DIR}/wp-config.php"
}

install_wp() {
    echo -e "\033[1;33m📥 Download WordPress...\033[0m"
    
    # Verifica spazio disco (modificato per maggiore accuratezza)
    local disk_space=$(df --output=avail / | tail -1 | tr -d ' ')
    if [ "$disk_space" -lt 1048576 ]; then  # Meno di 1GB disponibile
        echo -e "\033[0;31m❌ Spazio disco insufficiente! Minimo 1GB richiesto.\033[0m"
        exit 1
    fi
    
    # Download con 3 tentativi
    for i in {1..3}; do
        if wget -q https://wordpress.org/latest.tar.gz -P /tmp; then
            break
        elif [ "$i" -eq 3 ]; then
            echo -e "\033[0;31m❌ Download fallito dopo 3 tentativi!\033[0m"
            exit 1
        fi
        sleep 3
    done

    # Verifica integrità archivio
    if ! tar -tzf /tmp/latest.tar.gz >/dev/null; then
        echo -e "\033[0;31m❌ Archivio corrotto! Ricaricare...\033[0m"
        rm -f /tmp/latest.tar.gz
        exit 1
    fi

    # Estrazione con gestione errori
    if [ -d "${WP_DIR}" ]; then
        echo -e "\033[1;33mℹ Directory WordPress esistente, backup in corso...\033[0m"
        mv "${WP_DIR}" "${WP_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    mkdir -p "${WP_DIR}"
    tar -xzf /tmp/latest.tar.gz -C /var/www/html || {
        echo -e "\033[0;31m❌ Estrazione fallita! Verifica permessi e spazio.\033[0m"
        exit 1
    }

    # Verifica directory estratta
    local wp_temp="/var/www/html/wordpress"
    if [ -d "$wp_temp" ]; then
        if [ "$wp_temp" != "${WP_DIR}" ]; then
            mv "$wp_temp" "${WP_DIR}" || {
                echo -e "\033[0;31m❌ Spostamento fallito! Verifica permessi.\033[0m"
                exit 1
            }
        fi
    else
        echo -e "\033[0;31m❌ Directory WordPress non estratta correttamente!\033[0m"
        exit 1
    fi

    rm -f /tmp/latest.tar.gz
}

configure_nginx() {
    echo -e "\033[1;33m⚙️ Configurazione Nginx...\033[0m"
    
    local nginx_conf="/etc/nginx/sites-available/wordpress"
    
    # Backup configurazione esistente
    if [ -f "$nginx_conf" ]; then
        cp "$nginx_conf" "${nginx_conf}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    # Template con variabili
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

    # Abilita il sito
    ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/"

    if ! nginx -t; then
        echo -e "\033[0;31m❌ Configurazione Nginx non valida!\033[0m"
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