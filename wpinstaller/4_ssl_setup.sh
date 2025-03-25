#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    4_ssl_setup.sh                                     :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Generazione certificati con controlli avanzati
generate_ssl() {
    echo -e "\033[1;33m🔐 Generazione certificati SSL...\033[0m"
    
    mkdir -p /etc/nginx/ssl || {
        echo -e "\033[0;31m❌ Creazione directory SSL fallita!\033[0m"
        exit 1
    }
    
    # Generazione chiave privata
    if ! openssl genrsa -out "/etc/nginx/ssl/${DOMAIN}.key" 2048; then
        echo -e "\033[0;31m❌ Generazione chiave privata fallita!\033[0m"
        exit 1
    fi
    
    # Generazione CSR
    openssl req -new -key "/etc/nginx/ssl/${DOMAIN}.key" \
        -out "/etc/nginx/ssl/${DOMAIN}.csr" \
        -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_LOCALITY}/O=${SSL_ORG}/OU=${SSL_OU}/CN=${DOMAIN}/emailAddress=${ADMIN_EMAIL}" || {
        echo -e "\033[0;31m❌ Generazione CSR fallita!\033[0m"
        exit 1
    }
    
    # Generazione certificato
    if ! openssl x509 -req -days ${SSL_DAYS} \
        -in "/etc/nginx/ssl/${DOMAIN}.csr" \
        -signkey "/etc/nginx/ssl/${DOMAIN}.key" \
        -out "/etc/nginx/ssl/${DOMAIN}.crt"; then
        echo -e "\033[0;31m❌ Generazione certificato fallita!\033[0m"
        exit 1
    fi
}

echo -e "\033[1;36m🚀 Configurazione SSL...\033[0m"
validate_config
generate_ssl
configure_nginx_ssl

echo -e "\033[0;32m✅ SSL configurato correttamente\033[0m"