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

# ****************************************************************************** #
#                                                                                #
#           CONFIGURAZIONE LET'S ENCRYPT PER WORDPRESS - WSL/Win                 #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Verifica prerequisiti
check_prerequisites() {
    echo -e "\033[1;33m🔍 Verifica prerequisiti...\033[0m"
    
    # Verifica che il dominio non sia localhost
    if [ "$DOMAIN" = "localhost" ]; then
        echo -e "\033[0;31m❌ Let's Encrypt non supporta localhost!\033[0m"
        echo "Modifica 'DOMAIN' in wp_installer.cfg con un dominio valido"
        exit 1
    fi
    
    # Verifica che la porta 80 sia accessibile
    if ! nc -z localhost 80; then
        echo -e "\033[0;31m❌ Porta 80 non accessibile!\033[0m"
        echo "Necessaria per la verifica Let's Encrypt"
        exit 1
    fi
    
    # Verifica che il dominio risolva correttamente
    if ! dig +short "$DOMAIN" | grep -q '[0-9]'; then
        echo -e "\033[0;31m❌ Il dominio $DOMAIN non risolve correttamente!\033[0m"
        exit 1
    fi
}

# Installazione Certbot
install_certbot() {
    echo -e "\033[1;33m📦 Installazione Certbot...\033[0m"
    
    if ! command -v certbot >/dev/null; then
        apt update
        apt install -y certbot python3-certbot-nginx
    fi
}

# Ottenimento certificati
get_certificates() {
    echo -e "\033[1;33m🔐 Ottenimento certificati...\033[0m"
    
    certbot --nginx --non-interactive --agree-tos -m "$ADMIN_EMAIL" -d "$DOMAIN" --redirect
    local status=$?
    
    if [ $status -ne 0 ]; then
        echo -e "\033[0;31m❌ Ottenimento certificati fallito!\033[0m"
        echo "Risolvi i problemi e riprova:"
        echo "1. Verifica che il dominio punti al server"
        echo "2. Controlla che la porta 80 sia aperta"
        echo "3. Consulta /var/log/letsencrypt/letsencrypt.log"
        exit 1
    fi
}

# Configurazione rinnovo automatico
setup_renewal() {
    echo -e "\033[1;33m🔄 Configurazione rinnovo automatico...\033[0m"
    
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    
    # Test rinnovo
    if ! certbot renew --dry-run; then
        echo -e "\033[0;33m⚠️  Test rinnovo automatico fallito!\033[0m"
        echo "Controlla la configurazione manualmente con:"
        echo "certbot renew --dry-run"
    fi
}

# Main execution
echo -e "\033[1;36m🚀 Configurazione Let's Encrypt...\033[0m"
validate_config
check_prerequisites
install_certbot
get_certificates
setup_renewal

echo -e "\033[0;32m✅ Let's Encrypt configurato correttamente\033[0m"
echo -e "\033[1;33mℹ️  Certificati valido fino a: $(certbot certificates | grep 'Expiry Date' | cut -d: -f2)\033[0m"