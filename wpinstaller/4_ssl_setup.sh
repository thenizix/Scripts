#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    4_ssl_setup.sh                                    :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg

setup_self_signed() {
    echo -e "\033[1;33m🔐 Configurazione SSL autofirmato...\033[0m"
    
    local ssl_dir="/etc/nginx/ssl"
    mkdir -p "$ssl_dir"
    
    # Genera certificato solo se non esiste
    if [ ! -f "${ssl_dir}/${DOMAIN}.crt" ]; then
        openssl req -x509 -nodes -days ${SSL_DAYS} -newkey rsa:2048 \
            -keyout "${ssl_dir}/${DOMAIN}.key" \
            -out "${ssl_dir}/${DOMAIN}.crt" \
            -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_LOCALITY}/O=${SSL_ORG}/OU=${SSL_OU}/CN=${DOMAIN}/emailAddress=${ADMIN_EMAIL}"
        
        chmod 600 "${ssl_dir}/${DOMAIN}.key"
    else
        echo -e "\033[0;32m✔ Certificato già esistente\033[0m"
    fi
}

configure_nginx_ssl() {
    echo -e "\033[1;33m🔧 Configurazione Nginx per SSL...\033[0m"
    
    local nginx_conf="/etc/nginx/sites-available/wordpress"
    
    # Modifica configurazione solo se necessario
    if ! grep -q "listen 443 ssl" "$nginx_conf"; then
        # Backup
        cp "$nginx_conf" "${nginx_conf}.bak"
        
        # Aggiungi configurazione SSL
        sed -i "/server_name/a \    listen 443 ssl;\n    ssl_certificate /etc/nginx/ssl/${DOMAIN}.crt;\n    ssl_certificate_key /etc/nginx/ssl/${DOMAIN}.key;\n    ssl_protocols TLSv1.2 TLSv1.3;\n    ssl_ciphers ${SSL_CIPHERS};\n    ssl_prefer_server_ciphers on;" "$nginx_conf"
        
        # Aggiungi redirect HTTP->HTTPS
        sed -i "/server_name/a \    if (\$scheme != \"https\") {\n        return 301 https://\$host\$request_uri;\n    }" "$nginx_conf"
        
        # Verifica configurazione
        if ! nginx -t; then
            echo -e "\033[0;31m❌ Configurazione SSL non valida!\033[0m"
            mv "${nginx_conf}.bak" "$nginx_conf"
            return 1
        fi
    else
        echo -e "\033[0;32m✔ Configurazione SSL già presente\033[0m"
    fi
    
    systemctl reload nginx
}

# Main
echo -e "\033[1;36m🚀 Configurazione SSL...\033[0m"

setup_self_signed || exit 1
configure_nginx_ssl || exit 1

echo -e "\033[0;32m✅ Configurazione SSL completata\033[0m"