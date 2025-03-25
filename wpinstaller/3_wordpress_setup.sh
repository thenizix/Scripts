#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    3_wordpress_setup.sh                               :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

# ============================================================================== #
#                          INSTALLAZIONE WORDPRESS E NGINX                       #
# ============================================================================== #
# Questo script si occupa di:
# 1. Scaricare e configurare WordPress
# 2. Impostare i permessi corretti
# 3. Configurare Nginx per il sito WordPress
# ============================================================================== #

# Caricamento configurazioni condivise
source $(dirname "$0")/wp_installer.cfg

# ============================================================================== #
#                          IMPOSTAZIONI COLORI E FUNZIONI                        #
# ============================================================================== #
RED='\033[0;31m'    # Colore per errori
GREEN='\033[0;32m'  # Colore per successi
YELLOW='\033[1;33m' # Colore per avvisi
NC='\033[0m'        # Reset colore

# Funzione per verificare l'esito dei comandi
_check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FALLITO${NC}"
        exit 1
    fi
}

# ============================================================================== #
#                          INSTALLAZIONE WORDPRESS                               #
# ============================================================================== #
echo -e "${YELLOW}[1/3] Download e configurazione WordPress...${NC}"

# Download ultima versione WordPress
echo -n "Download ultima versione... "
wget -q https://wordpress.org/latest.tar.gz -P /tmp
_check

# Estrazione archivio
echo -n "Estrazione files... "
tar -xzf /tmp/latest.tar.gz -C /var/www/html
_check

# Rinominazione directory
echo -n "Configurazione directory... "
mv /var/www/html/wordpress "$WP_DIR"
_check

# Pulizia archivio temporaneo
echo -n "Pulizia files temporanei... "
rm -f /tmp/latest.tar.gz
_check

# ============================================================================== #
#                          CONFIGURAZIONE PERMESSI                               #
# ============================================================================== #
echo -e "${YELLOW}\n[2/3] Configurazione permessi...${NC}"

# Impostazione proprietario
echo -n "Impostazione proprietario (www-data)... "
chown -R www-data:www-data "$WP_DIR"
_check

# Impostazione permessi directory
echo -n "Impostazione permessi directory (750)... "
find "$WP_DIR" -type d -exec chmod 750 {} \;
_check

# Impostazione permessi file
echo -n "Impostazione permessi file (640)... "
find "$WP_DIR" -type f -exec chmod 640 {} \;
_check

# Permessi speciali per wp-content
echo -n "Permessi speciali wp-content... "
chmod -R 770 "$WP_DIR/wp-content"
_check

# ============================================================================== #
#                          CONFIGURAZIONE NGINX                                  #
# ============================================================================== #
echo -e "${YELLOW}\n[3/3] Configurazione Nginx...${NC}"

# Creazione configurazione sito
echo -n "Creazione virtual host... "
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $WP_DIR;

    index index.php index.html index.htm;

    access_log /var/log/nginx/wordpress.access.log;
    error_log /var/log/nginx/wordpress.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
_check

# Abilitazione sito
echo -n "Abilitazione sito... "
ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
_check

# Disabilitazione configurazione di default
echo -n "Disabilitazione sito default... "
rm -f /etc/nginx/sites-enabled/default
_check

# Test configurazione
echo -n "Verifica configurazione Nginx... "
nginx -t 2>/dev/null
_check

# Riavvio Nginx
echo -n "Riavvio servizio Nginx... "
systemctl restart nginx
_check

# ============================================================================== #
#                          VERIFICA FINALE                                       #
# ============================================================================== #
echo -e "${YELLOW}\nVerifica installazione...${NC}"

echo -n "Verifica file WordPress... "
[ -f "$WP_DIR/wp-config-sample.php" ] || [ -f "$WP_DIR/wp-config.php" ]
_check

echo -n "Verifica risposta HTTP... "
curl -Is http://$DOMAIN | grep -q "HTTP/1.1 200 OK"
_check

# ============================================================================== #
#                          FINE SCRIPT                                           #
# ============================================================================== #
echo -e "${GREEN}\nFase 3 completata con successo!${NC}"
echo -e "Procedi con l'esecuzione di: ${YELLOW}./4_ssl_setup.sh${NC}"


#===testare manualmente====
# Verifica permessi
#ls -la $WP_DIR

# Verifica configurazione Nginx
#nginx -T | grep "server_name "

# Test risposta HTTP
#curl -I http://$DOMAIN
