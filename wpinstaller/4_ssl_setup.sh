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

generate_ssl() {
    echo -e "\033[1;33m🔐 Generazione certificati SSL...\033[0m"
    
    local ssl_dir="/etc/nginx/ssl"
    mkdir -p "$ssl_dir" || {
        echo -e "\033[0;31m❌ Creazione directory SSL fallita!\033[0m"
        exit 1
    }
    
    # Generazione chiave privata con verifica
    if ! openssl genrsa -out "${ssl_dir}/${DOMAIN}.key" 2048; then
        echo -e "\033[0;31m❌ Generazione chiave privata fallita!\033[0m"
        exit 1
    fi
    
    # Generazione CSR
    if ! openssl req -new -key "${ssl_dir}/${DOMAIN}.key" \
        -out "${ssl_dir}/${DOMAIN}.csr" \
        -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_LOCALITY}/O=${SSL_ORG}/OU=${SSL_OU}/CN=${DOMAIN}/emailAddress=${ADMIN_EMAIL}"; then
        echo -e "\033[0;31m❌ Generazione CSR fallita!\033[0m"
        exit 1
    fi
    
    # Generazione certificato autofirmato
    if ! openssl x509 -req -days ${SSL_DAYS} \
        -in "${ssl_dir}/${DOMAIN}.csr" \
        -signkey "${ssl_dir}/${DOMAIN}.key" \
        -out "${ssl_dir}/${DOMAIN}.crt"; then
        echo -e "\033[0;31m❌ Generazione certificato fallita!\033[0m"
        exit 1
    fi

    # Imposta permessi sicuri
    chmod 600 "${ssl_dir}/${DOMAIN}.key"
}

configure_nginx_ssl() {
    echo -e "\033[1;33m🔧 Configurazione Nginx per SSL...\033[0m"
    
    local nginx_conf="/etc/nginx/sites-available/wordpress"
    
    # Backup configurazione
    cp "$nginx_conf" "${nginx_conf}.pre-ssl"
    
    # Modifica configurazione per SSL
    sed -i "/listen 80;/a \    listen 443 ssl http2;\n    ssl_certificate /etc/nginx/ssl/${DOMAIN}.crt;\n    ssl_certificate_key /etc/nginx/ssl/${DOMAIN}.key;\n    ssl_protocols TLSv1.2 TLSv1.3;\n    ssl_ciphers ${SSL_CIPHERS};\n    ssl_prefer_server_ciphers on;" "$nginx_conf"
    
    # Redirect HTTP to HTTPS
    sed -i "/server_name/a \    if (\$scheme != \"https\") {\n        return 301 https://\$host\$request_uri;\n    }" "$nginx_conf"
    
    if ! nginx -t; then
        echo -e "\033[0;31m❌ Configurazione SSL non valida! Ripristino...\033[0m"
        mv "${nginx_conf}.pre-ssl" "$nginx_conf"
        exit 1
    fi
    
    systemctl reload nginx
}

echo -e "\033[1;36m🚀 Configurazione SSL...\033[0m"
validate_config
generate_ssl
configure_nginx_ssl

echo -e "\033[0;32m✅ SSL configurato correttamente\033[0m"