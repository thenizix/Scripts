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

# ****************************************************************************** #
#                                                                                #
#         INSTALLAZIONE E CONFIGURAZIONE AVANZATA WORDPRESS - WSL/Win            #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Funzione per scaricare e installare WordPress
install_wp() {
    echo -e "\033[1;33m📥 Download WordPress...\033[0m"
    
    # Pulizia installazioni precedenti
    rm -rf "${WP_DIR}"
    
    # Download ultima versione
    if ! wget -q https://wordpress.org/latest.tar.gz -P /tmp; then
        echo -e "\033[0;31m❌ Download fallito!\033[0m"
        exit 1
    fi
    
    # Estrazione
    if ! tar -xzf /tmp/latest.tar.gz -C /var/www/html; then
        echo -e "\033[0;31m❌ Estrazione fallita!\033[0m"
        exit 1
    fi
    
    # Rinominazione directory (se diversa da WP_DIR)
    if [ "/var/www/html/wordpress" != "${WP_DIR}" ]; then
        mv "/var/www/html/wordpress" "${WP_DIR}" || {
            echo -e "\033[0;31m❌ Spostamento directory fallito!\033[0m"
            exit 1
        }
    fi
    
    # Pulizia
    rm -f /tmp/latest.tar.gz
}

# Funzione per impostare i permessi corretti
set_permissions() {
    echo -e "\033[1;33m🔒 Impostazione permessi...\033[0m"
    
    # Proprietario
    chown -R www-data:www-data "${WP_DIR}"
    
    # Permessi directory
    find "${WP_DIR}" -type d -exec chmod 750 {} \;
    
    # Permessi file
    find "${WP_DIR}" -type f -exec chmod 640 {} \;
    
    # Permessi speciali
    chmod 600 "${WP_DIR}/wp-config.php" 2>/dev/null
    chmod 770 "${WP_DIR}/wp-content"
    chmod 770 "${WP_DIR}/wp-content/uploads"
}

# Funzione per configurare Nginx
configure_nginx() {
    echo -e "\033[1;33m⚙️ Configurazione Nginx...\033[0m"
    
    # Configurazione base
    cat > /etc/nginx/sites-available/wordpress <<EOF
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

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        expires max;
        log_not_found off;
    }
}
EOF

    # Abilita sito
    ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configurazione
    if ! nginx -t; then
        echo -e "\033[0;31m❌ Configurazione Nginx non valida!\033[0m"
        exit 1
    fi
    
    systemctl reload nginx
}

# Main execution
echo -e "\033[1;36m🚀 Installazione WordPress...\033[0m"
validate_config
install_wp
set_permissions
configure_nginx

echo -e "\033[0;32m✅ WordPress installato correttamente\033[0m"