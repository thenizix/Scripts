#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    wordpress_nginx_installer.sh                       :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <student@nowhere>                 +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 10:00:00 by Thenizix          #+#    #+#                #
#    Updated: 2025/03/25 10:00:00 by TheNizix         ###   ########.it          #
#                                                                                #
# ****************************************************************************** #
# ============================================================================== #
#                             CONFIGURAZIONE VARIABILI                           #
# ============================================================================== #
MYSQL_ROOT_PASS="Superbanana1"          # Password per root di MySQL
MYSQL_WP_USER="wpuser"                  # Utente database WordPress
MYSQL_WP_PASS="Superbanana1"            # Password utente WordPress
MYSQL_WP_DB="wordpress"                 # Nome database WordPress
WP_DIR="/var/www/html/wordpress"        # Directory installazione WordPress
DOMAIN="localhost"                      # Dominio per configurazione Nginx
PHP_VERSION="8.3"                       # Versione PHP da installare

# ============================================================================== #
#                             VARIABILI DI STILE                                 #
# ============================================================================== #
RED='\033[0;31m'                        # Colore rosso per errori
GREEN='\033[0;32m'                      # Colore verde per successi
YELLOW='\033[1;33m'                     # Colore giallo per avvisi
NC='\033[0m'                            # Reset colore

# ============================================================================== #
#                             FUNZIONI DI UTILITÀ                                #
# ============================================================================== #

# Funzione per verificare il successo di un comando
_check_success() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Errore: $1 fallito${NC}"
        exit 1
    else
        echo -e "${GREEN}$1 completato con successo${NC}"
    fi
}

# Funzione per installare pacchetti con controllo errori
_install_packages() {
    echo -e "${YELLOW}Installazione pacchetti: $@...${NC}"
    apt install -y $@ > /dev/null 2>&1
    _check_success "Installazione pacchetti $@"
}

# ============================================================================== #
#                             INIZIO INSTALLAZIONE                               #
# ============================================================================== #

echo -e "${GREEN}
==============================================================================
                INSTALLAZIONE WORDPRESS SU NGINX (WSL Ubuntu)
==============================================================================
${NC}"

# Verifica che lo script sia eseguito come root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Per favore esegui lo script come root${NC}"
    exit 1
fi

# ============================================================================== #
#                          AGGIORNAMENTO DEL SISTEMA                             #
# ============================================================================== #
echo -e "${YELLOW}[1/10] Aggiornamento del sistema...${NC}"
apt update && apt upgrade -y
_check_success "Aggiornamento sistema"

# ============================================================================== #
#                          INSTALLAZIONE NGINX                                   #
# ============================================================================== #
echo -e "${YELLOW}[2/10] Installazione Nginx...${NC}"
_install_packages nginx
systemctl enable nginx --now

# ============================================================================== #
#                          INSTALLAZIONE PHP E ESTENSIONI                        #
# ============================================================================== #
echo -e "${YELLOW}[3/10] Installazione PHP $PHP_VERSION e estensioni...${NC}"
_install_packages php$PHP_VERSION-fpm php$PHP_VERSION-mysql php$PHP_VERSION-curl \
                  php$PHP_VERSION-gd php$PHP_VERSION-intl php$PHP_VERSION-mbstring \
                  php$PHP_VERSION-soap php$PHP_VERSION-xml php$PHP_VERSION-xmlrpc \
                  php$PHP_VERSION-zip php$PHP_VERSION-opcache

# ============================================================================== #
#                          CONFIGURAZIONE PHP                                    #
# ============================================================================== #
echo -e "${YELLOW}[4/10] Configurazione PHP...${NC}"
sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/$PHP_VERSION/fpm/php.ini
sed -i 's/^expose_php = On/expose_php = Off/' /etc/php/$PHP_VERSION/fpm/php.ini
echo "php_admin_flag[expose_php] = off" >> /etc/php/$PHP_VERSION/fpm/pool.d/www.conf
systemctl restart php$PHP_VERSION-fpm
_check_success "Configurazione PHP"

# ============================================================================== #
#                          INSTALLAZIONE E SICUREZZA MARIADB                     #
# ============================================================================== #
echo -e "${YELLOW}[5/10] Installazione MariaDB...${NC}"
_install_packages mariadb-server mariadb-client

echo -e "${YELLOW}[6/10] Configurazione sicurezza MariaDB...${NC}"
mysql -u root <<-EOF
    ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    FLUSH PRIVILEGES;
EOF
_check_success "Configurazione sicurezza MariaDB"

# ============================================================================== #
#                          CREAZIONE DATABASE WORDPRESS                          #
# ============================================================================== #
echo -e "${YELLOW}[7/10] Creazione database WordPress...${NC}"
mysql -u root -p$MYSQL_ROOT_PASS <<-EOF
    CREATE DATABASE $MYSQL_WP_DB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER '$MYSQL_WP_USER'@'localhost' IDENTIFIED BY '$MYSQL_WP_PASS';
    GRANT ALL PRIVILEGES ON $MYSQL_WP_DB.* TO '$MYSQL_WP_USER'@'localhost';
    FLUSH PRIVILEGES;
EOF
_check_success "Creazione database WordPress"

# ============================================================================== #
#                          INSTALLAZIONE WORDPRESS                               #
# ============================================================================== #
echo -e "${YELLOW}[8/10] Installazione WordPress...${NC}"
if [ -d "$WP_DIR" ]; then
    rm -rf $WP_DIR
fi

wget https://wordpress.org/latest.tar.gz -P /tmp
tar -xzvf /tmp/latest.tar.gz -C /var/www/html
mv /var/www/html/wordpress $WP_DIR
chown -R www-data:www-data $WP_DIR
find $WP_DIR -type d -exec chmod 750 {} \;
find $WP_DIR -type f -exec chmod 640 {} \;
_check_success "Installazione WordPress"

# ============================================================================== #
#                          CONFIGURAZIONE NGINX                                  #
# ============================================================================== #
echo -e "${YELLOW}[9/10] Configurazione Nginx...${NC}"
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
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { log_not_found off; access_log off; allow all; }
    location ~* \.(css|gif|ico|jpeg|jpg|js|png)\$ { expires max; log_not_found off; }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
}
EOF

ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
_check_success "Configurazione Nginx"

# ============================================================================== #
#                          VERIFICHE FINALI                                      #
# ============================================================================== #
echo -e "${YELLOW}[10/10] Verifiche finali...${NC}"
echo "<?php phpinfo(); ?>" > $WP_DIR/info.php
curl -s http://$DOMAIN/info.php | grep "PHP Version" || echo -e "${RED}Test PHP fallito${NC}"
rm -f $WP_DIR/info.php

# ============================================================================== #
#                          REPORT INSTALLAZIONE                                  #
# ============================================================================== #
cat > /root/wordpress_install_report.txt <<EOF
=== REPORT INSTALLAZIONE WORDPRESS ===
Data: $(date)
Sistema: $(lsb_release -d | cut -f2-) $(uname -m)

CREDENZIALI DATABASE:
- Root Password: $MYSQL_ROOT_PASS
- Nome Database: $MYSQL_WP_DB
- Utente DB: $MYSQL_WP_USER
- Password DB: $MYSQL_WP_PASS

PERCORSI IMPORTANTI:
- Directory WordPress: $WP_DIR
- Config Nginx: /etc/nginx/sites-available/wordpress
- Config PHP: /etc/php/$PHP_VERSION/fpm/php.ini

COMANDI DI SERVIZIO:
- Avvio MySQL: sudo systemctl start mariadb
- Avvio PHP-FPM: sudo systemctl start php$PHP_VERSION-fpm
- Avvio Nginx: sudo systemctl start nginx

URL DI TEST:
- Sito WordPress: http://$DOMAIN
EOF

echo -e "${GREEN}
==============================================================================
INSTALLAZIONE COMPLETATA CON SUCCESSO!
==============================================================================
${YELLOW}Per accedere a WordPress: http://$DOMAIN
${GREEN}Un report completo è stato salvato in /root/wordpress_install_report.txt
${NC}"

# ============================================================================== #
#                          COMMENTI FINALI                                       #
# ============================================================================== #
# 
# Questo script automatizza l'installazione di WordPress su Nginx in ambiente WSL.
#
# Caratteristiche principali:
# 1. Configurazione sicura di MySQL con password personalizzate
# 2. Installazione ottimizzata per PHP 8.3
# 3. Configurazione Nginx con security headers
# 4. Creazione automatica di un report con tutte le credenziali
# 5. Verifica automatica di ogni passaggio
#
# Per problemi noti e soluzioni:
# - Se Nginx non si avvia, verificare con 'nginx -t'
# - Se PHP non risponde, controllare 'systemctl status php$PHP_VERSION-fpm'
# - Per problemi di permessi, eseguire 'chown -R www-data:www-data $WP_DIR'
#
# 42 Firenze -theNizix  2025 - Progetto WordPress/Nginx
#
# ============================================================================== #