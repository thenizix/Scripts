#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    6_letsencrypt.sh                                  :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg

check_prerequisites() {
    echo -e "\033[1;33m🔍 Verifica prerequisiti Let's Encrypt...\033[0m"
    
    # Verifica porta 80
    if ! ss -tulpn | grep -q ':80 '; then
        echo -e "\033[0;31m❌ Porta 80 non in ascolto! Necessaria per la validazione\033[0m"
        exit 1
    fi
    
    # Verifica dominio pubblico
    if [[ "$DOMAIN" == "localhost" ]]; then
        echo -e "\033[0;31m❌ Let's Encrypt non supporta 'localhost' come dominio!\033[0m"
        exit 1
    fi
    
    # Verifica risoluzione DNS
    if ! dig +short "$DOMAIN" | grep -q .; then
        echo -e "\033[0;31m❌ Il dominio ${DOMAIN} non risolve correttamente\033[0m"
        exit 1
    fi
}

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

get_certificates() {
    echo -e "\033[1;33m🪙 Richiesta certificati Let's Encrypt...\033[0m"
    
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" || {
        echo -e "\033[0;31m❌ Ottenimento certificati fallito!\033[0m"
        exit 1
    }
    
    # Configura rinnovo automatico
    (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet") | crontab -
    echo -e "\033[0;32m✔ Rinnovo automatico configurato\033[0m"
}

echo -e "\033[1;36m🚀 Configurazione Let's Encrypt...\033[0m"
validate_config
check_prerequisites
install_certbot
get_certificates

echo -e "\033[0;32m✅ Let's Encrypt configurato correttamente\033[0m"