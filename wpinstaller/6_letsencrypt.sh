#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    6_letsencrypt.sh                                   :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Verifica completa prerequisiti
check_prerequisites() {
    echo -e "\033[1;33m🔍 Verifica prerequisiti...\033[0m"
    
    # Verifica porta 80
    ss -tulpn | grep ':80 ' || {
        echo -e "\033[0;31m❌ Porta 80 non in ascolto! Necessaria per la validazione\033[0m"
        exit 1
    }
    
    # Verifica risoluzione DNS
    dig +short "$DOMAIN" | grep -q . || {
        echo -e "\033[0;31m❌ Il dominio ${DOMAIN} non risolve correttamente\033[0m"
        exit 1
    }
}

# Installazione Certbot con gestione errori
install_certbot() {
    echo -e "\033[1;33m📦 Installazione Certbot...\033[0m"
    
    if ! command -v certbot >/dev/null; then
        apt-get update -qq
        apt-get install -qq -y certbot python3-certbot-nginx || {
            echo -e "\033[0;31m❌ Installazione Certbot fallita!\033[0m"
            exit 1
        }
    fi
}

echo -e "\033[1;36m🚀 Configurazione Let's Encrypt...\033[0m"
validate_config
check_prerequisites
install_certbot
get_certificates

echo -e "\033[0;32m✅ Let's Encrypt configurato correttamente\033[0m"