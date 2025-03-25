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

# ============================================================================== #
#                          CONFIGURAZIONE SSL E HARDENING                        #
# ============================================================================== #
# Questo script si occupa di:
# 1. Generazione certificati SSL self-signed
# 2. Configurazione Nginx per HTTPS
# 3. Hardening del server web
# 4. Ottimizzazioni TLS
# ============================================================================== #

source $(dirname "$0")/wp_installer.cfg

# ============================================================================== #
#                          IMPOSTAZIONI COLORI E FUNZIONI                        #
# ============================================================================== #
RED='\033[0;31m'    # Colore per errori
GREEN='\033[0;32m'  # Colore per successi
YELLOW='\033[1;33m' # Colore per avvisi
NC='\033[0m'        # Reset colore

_check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FALLITO${NC}"
        exit 1
    fi
}

# ============================================================================== #
#                          CREAZIONE CERTIFICATI SSL                             #
# ============================================================================== #
echo -e "${YELLOW}[1/4] Configurazione SSL...${NC}"

echo -n "Creazione directory certificati... "
mkdir -p /etc/nginx/ssl
_check

echo -n "Generazione chiave privata... "
openssl genrsa -out /etc/nginx/ssl/${DOMAIN}.key 2048 >/dev/null 2>&1
_check

echo -n "Generazione CSR... "
openssl req -new -key /etc/nginx/ssl/${DOMAIN}.key \
    -out /etc/nginx/ssl/${DOMAIN}.csr \
    -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_LOCALITY}/O=${SSL_ORG}/CN=${DOMAIN}" >/dev/null 2>&1
_check

echo -n "Generazione certificato autofirmato... "
openssl x509 -req -days ${SSL_DAYS} \
    -in /etc/nginx/ssl/${DOMAIN}.csr \
    -signkey /etc/nginx/ssl/${DOMAIN}.key \
    -out /etc/nginx/ssl/${DOMAIN}.crt >/dev/null 2>&1
_check

# ============================================================================== #
#                          CONFIGURAZIONE NGINX HTTPS                            #
# ============================================================================== #
echo -e "${YELLOW}[2/4] Configurazione Nginx per HTTPS...${NC}"

echo -n "Creazione configurazione SSL... "
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    root ${WP_DIR};

    ssl_certificate /etc/nginx/ssl/${DOMAIN}.crt;
    ssl_certificate_key /etc/nginx/ssl/${DOMAIN}.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
_check

# ============================================================================== #
#                          HARDENING SERVER                                      #
# ============================================================================== #
echo -e "${YELLOW}[3/4] Hardening del server...${NC}"

echo -n "Configurazione header di sicurezza... "
cat >> /etc/nginx/sites-available/wordpress <<EOF
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
EOF
_check

echo -n "Protezione file sensibili... "
cat >> /etc/nginx/sites-available/wordpress <<EOF
    location = /wp-config.php { deny all; }
    location = /xmlrpc.php { deny all; }
EOF
_check

# ============================================================================== #
#                          APPLICAZIONE MODIFICHE                                #
# ============================================================================== #
echo -e "${YELLOW}[4/4] Applicazione modifiche...${NC}"

echo -n "Test configurazione Nginx... "
nginx -t >/dev/null 2>&1
_check

echo -n "Riavvio servizi... "
systemctl restart nginx php${PHP_VERSION}-fpm
_check

# ============================================================================== #
#                          VERIFICA FINALE                                       #
# ============================================================================== #
echo -e "${YELLOW}\nVerifica configurazione SSL...${NC}"

echo -n "Connessione HTTPS... "
curl -ks https://${DOMAIN} | grep -q "WordPress" || curl -ks https://localhost | grep -q "WordPress"
_check

echo -n "Verifica protocolli SSL... "
openssl s_client -connect ${DOMAIN}:443 -tls1_2 2>/dev/null | grep -q "Protocol.*TLSv1.2"
_check

# ============================================================================== #
#                          FINE SCRIPT                                           #
# ============================================================================== #
echo -e "${GREEN}\nFase 4 completata con successo!${NC}"
echo -e "Certificato SSL autofirmato valido per ${SSL_DAYS} giorni"
echo -e "Posizione certificati:"
echo -e "  - Certificato: ${YELLOW}/etc/nginx/ssl/${DOMAIN}.crt${NC}"
echo -e "  - Chiave privata: ${YELLOW}/etc/nginx/ssl/${DOMAIN}.key${NC}"
echo -e "Per sostituire con certificati Let's Encrypt, eseguire: ${YELLOW}./6_letsencrypt.sh${NC}"

#====Verifica manuale====
# Verifica certificato
#openssl x509 -in /etc/nginx/ssl/${DOMAIN}.crt -text -noout

# Test vulnerabilità SSL
#sslyze --regular ${DOMAIN}

# Verifica headers di sicurezza
#curl -I https://${DOMAIN}