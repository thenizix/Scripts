#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    4_ssl_setup.sh                                     :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.it          #
#                                                                                #
# ****************************************************************************** #

# Configurazioni
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"
source "${CONFIG_DIR}/wp_installer.cfg" || {
    echo -e "\033[0;31m❌ Errore nel caricamento della configurazione\033[0m" >&2
    exit 1
}

# Verifica permessi root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[0;31m❌ Lo script deve essere eseguito come root!\033[0m" >&2
    exit 1
}

# Funzione per Let's Encrypt
setup_letsencrypt() {
    echo -e "\033[1;34mConfigurazione Let's Encrypt...\033[0m"
    if ! command -v certbot >/dev/null; then
        echo -e "\033[0;31m❌ Certbot non installato! Esegui prima 1_system_setup.sh\033[0m" >&2
        exit 1
    fi

    # Ottieni certificato
    if ! certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${ADMIN_EMAIL}"; then
        echo -e "\033[0;31m❌ Errore nella generazione del certificato\033[0m" >&2
        exit 1
    fi

    # Aggiungi rinnovo automatico a cron
    (crontab -l 2>/dev/null; echo "0 12 * * * certbot renew --quiet") | crontab -
}

# Funzione per Self-Signed
setup_selfsigned() {
    echo -e "\033[1;34mConfigurazione certificato self-signed...\033[0m"
    mkdir -p /etc/ssl/{certs,private}
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/nginx-selfsigned.key \
        -out /etc/ssl/certs/nginx-selfsigned.crt \
        -subj "/CN=${DOMAIN}" 2>/dev/null || {
        echo -e "\033[0;31m❌ Errore nella generazione del certificato\033[0m" >&2
        exit 1
    }
}

# Main
echo -e "\033[1;36m=== CONFIGURAZIONE SSL (${SSL_TYPE}) ===\033[0m"

case "$SSL_TYPE" in
    letsencrypt) setup_letsencrypt ;;
    selfsigned) setup_selfsigned ;;
    none) echo -e "\033[1;33m⚠ SSL disabilitato\033[0m"; exit 0 ;;
    *) echo -e "\033[0;31m❌ Tipo SSL non valido: ${SSL_TYPE}\033[0m" >&2; exit 1 ;;
esac

# Riavvia Nginx
systemctl restart nginx
echo -e "\033[0;32m✅ SSL configurato correttamente!\033[0m"