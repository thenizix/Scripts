#!/bin/bash
# CONFIGURAZIONE SSL

set -euo pipefail
trap 'echo "Errore a linea $LINENO"; exit 1' ERR

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/ssl_setup.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# Funzioni
generate_selfsigned() {
    echo "🔐 Generazione certificato self-signed..." | tee -a "$LOG_FILE"
    sudo mkdir -p /etc/ssl/{certs,private}
    sudo chmod 700 /etc/ssl/private
    
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/nginx-selfsigned.key \
        -out /etc/ssl/certs/nginx-selfsigned.crt \
        -subj "/CN=${DOMAIN}" \
        -addext "subjectAltName=DNS:${DOMAIN}" 2>&1 | tee -a "$LOG_FILE"
    
    # Configurazione Diffie-Hellman
    sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048 2>&1 | tee -a "$LOG_FILE"
}

# Main process
{
    echo "=== CONFIGURAZIONE SSL ==="

    case "${SSL_TYPE}" in
        letsencrypt)
            if [ "${DOMAIN}" = "localhost" ]; then
                echo "❌ Let's Encrypt non supporta localhost" | tee -a "$LOG_FILE"
                exit 1
            fi
            
            echo "📦 Installazione Certbot..." | tee -a "$LOG_FILE"
            sudo apt-get install -y certbot python3-certbot-nginx | tee -a "$LOG_FILE"
            
            echo "🔐 Richiesta certificato..." | tee -a "$LOG_FILE"
            sudo certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${ADMIN_EMAIL}" | tee -a "$LOG_FILE"
            ;;
            
        selfsigned)
            generate_selfsigned
            ;;
            
        none)
            echo "ℹ️ SSL disabilitato" | tee -a "$LOG_FILE"
            exit 0
            ;;
            
        *)
            echo "❌ Tipo SSL non valido: ${SSL_TYPE}" | tee -a "$LOG_FILE"
            exit 1
            ;;
    esac

    # Riavvio Nginx
    echo "🔄 Riavvio Nginx..." | tee -a "$LOG_FILE"
    if grep -qi "microsoft" /proc/version; then
        sudo service nginx restart | tee -a "$LOG_FILE"
    else
        sudo systemctl restart nginx | tee -a "$LOG_FILE"
    fi

    echo "✅ Configurazione SSL completata!" | tee -a "$LOG_FILE"
}