#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    4_ssl_setup.sh                                    :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@student.42.fr>          +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/06/01 17:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/06/11 10:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# ============================================================================== #
# INIZIALIZZAZIONE
# ============================================================================== #
set -eo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/ssl_setup.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================================== #
# FUNZIONI DI SUPPORTO
# ============================================================================== #

genera_self_signed() {
    echo "🔐 Generazione certificato self-signed..."
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/nginx-selfsigned.key \
        -out /etc/ssl/certs/nginx-selfsigned.crt \
        -subj "/CN=${DOMAIN}"
}

# ============================================================================== #
# MAIN
# ============================================================================== #
{
    echo "🚀 Inizio configurazione SSL"
    
    case "$SSL_TYPE" in
        letsencrypt)
            if [ "$DOMAIN" = "localhost" ]; then
                echo "❌ Let's Encrypt non supporta localhost"
                exit 1
            fi
            
            echo "📦 Installazione Certbot..."
            sudo apt-get install -y certbot python3-certbot-nginx
            
            echo "🔐 Richiesta certificato..."
            sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL"
            ;;
            
        selfsigned)
            genera_self_signed
            ;;
            
        none)
            echo "ℹ️ SSL disabilitato"
            exit 0
            ;;
    esac
    
    # Riavvio Nginx
    echo "🔄 Riavvio Nginx..."
    if grep -qi microsoft /proc/version; then
        sudo service nginx restart
    else
        sudo systemctl restart nginx
    fi
    
    echo "✅ Configurazione SSL completata!"
} 2>&1 | tee -a "$LOG_FILE"
