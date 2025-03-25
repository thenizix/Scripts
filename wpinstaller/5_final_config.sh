#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    5_final_config.sh                                  :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

# ============================================================================== #
#                          OTTIMIZZAZIONI FINALI                                 #
# ============================================================================== #
# Questo script completa l'installazione con:
# 1. Ottimizzazione PHP-FPM
# 2. Configurazione WordPress
# 3. Impostazioni di sicurezza aggiuntive
# 4. Configurazione automatica cron jobs
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
#                          OTTIMIZZAZIONE PHP-FPM                                #
# ============================================================================== #
echo -e "${YELLOW}[1/4] Ottimizzazione PHP-FPM...${NC}"

echo -n "Configurazione pool PHP... "
cat > /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf <<EOF
[www]
user = www-data
group = www-data
listen = /run/php/php${PHP_VERSION}-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 25
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests = 500
php_admin_value[upload_max_filesize] = 64M
php_admin_value[post_max_size] = 64M
php_admin_value[memory_limit] = 256M
php_admin_value[max_execution_time] = 300
php_admin_value[expose_php] = off
EOF
_check

# ============================================================================== #
#                          CONFIGURAZIONE WORDPRESS                              #
# ============================================================================== #
echo -e "${YELLOW}[2/4] Configurazione WordPress...${NC}"

echo -n "Creazione wp-config.php... "
cat > ${WP_DIR}/wp-config.php <<EOF
<?php
define('DB_NAME', '${MYSQL_WP_DB}');
define('DB_USER', '${MYSQL_WP_USER}');
define('DB_PASSWORD', '${MYSQL_WP_PASS}');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
define('AUTH_KEY',         '$(openssl rand -base64 48)');
define('SECURE_AUTH_KEY',  '$(openssl rand -base64 48)');
define('LOGGED_IN_KEY',    '$(openssl rand -base64 48)');
define('NONCE_KEY',        '$(openssl rand -base64 48)');
define('AUTH_SALT',        '$(openssl rand -base64 48)');
define('SECURE_AUTH_SALT', '$(openssl rand -base64 48)');
define('LOGGED_IN_SALT',   '$(openssl rand -base64 48)');
define('NONCE_SALT',       '$(openssl rand -base64 48)');
define('WP_HOME', 'https://${DOMAIN}');
define('WP_SITEURL', 'https://${DOMAIN}');
define('WP_AUTO_UPDATE_CORE', true);
define('FS_METHOD', 'direct');
define('WP_HTTP_BLOCK_EXTERNAL', true);
define('WP_ACCESSIBLE_HOSTS', '*.github.com,*.wordpress.org');
\$table_prefix = 'wp_';
if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOF
_check

echo -n "Impostazione permessi wp-config.php... "
chmod 640 ${WP_DIR}/wp-config.php
chown www-data:www-data ${WP_DIR}/wp-config.php
_check

# ============================================================================== #
#                          SICUREZZA AGGIUNTIVA                                  #
# ============================================================================== #
echo -e "${YELLOW}[3/4] Hardening aggiuntivo...${NC}"

echo -n "Disabilitazione editor integrato... "
cat >> ${WP_DIR}/wp-config.php <<EOF
define('DISALLOW_FILE_EDIT', true);
EOF
_check

echo -n "Configurazione file .htaccess... "
cat > ${WP_DIR}/.htaccess <<EOF
# Blocca accesso a file sensibili
<FilesMatch "^(wp-config\.php|xmlrpc\.php)">
    Require all denied
</FilesMatch>

# Protezione cartelle
Options -Indexes

# Blocca hotlinking
RewriteEngine On
RewriteCond %{HTTP_REFERER} !^$
RewriteCond %{HTTP_REFERER} !^https://${DOMAIN} [NC]
RewriteRule \.(jpg|jpeg|png|gif)$ - [NC,F,L]
EOF
_check

# ============================================================================== #
#                          MANUTENZIONE AUTOMATICA                               #
# ============================================================================== #
echo -e "${YELLOW}[4/4] Configurazione manutenzione...${NC}"

echo -n "Pulizia automatica aggiornamenti... "
(crontab -l 2>/dev/null; echo "0 3 * * * find ${WP_DIR}/wp-content/upgrade/ -type d -mtime +7 -exec rm -rf {} +") | crontab -
_check

echo -n "Backup automatico database... "
(crontab -l 2>/dev/null; echo "0 2 * * * mysqldump -u ${MYSQL_WP_USER} -p'${MYSQL_WP_PASS}' ${MYSQL_WP_DB} | gzip > /var/backups/wp_db_\$(date +\%Y\%m\%d).sql.gz") | crontab -
_check

# ============================================================================== #
#                          RIAVVIO SERVIZI                                       #
# ============================================================================== #
echo -e "${YELLOW}\nRiavvio servizi...${NC}"

echo -n "Riavvio PHP-FPM... "
systemctl restart php${PHP_VERSION}-fpm
_check

echo -n "Riavvio Nginx... "
systemctl restart nginx
_check

# ============================================================================== #
#                          VERIFICA FINALE                                       #
# ============================================================================== #
echo -e "${YELLOW}\nVerifica finale configurazione...${NC}"

echo -n "Verifica connessione database... "
wp --path=${WP_DIR} db check >/dev/null 2>&1
_check

echo -n "Verifica HTTPS funzionante... "
curl -Is https://${DOMAIN} | grep -q "HTTP/.* 200"
_check

# ============================================================================== #
#                          FINE SCRIPT                                           #
# ============================================================================== #
echo -e "${GREEN}\nConfigurazione completata con successo!${NC}"
echo -e "Accesso al sito: ${YELLOW}https://${DOMAIN}${NC}"
echo -e "Credenziali amministratore WordPress:"
echo -e "  - Database: ${YELLOW}${MYSQL_WP_USER} / ${MYSQL_WP_PASS}${NC}"
echo -e "  - File di configurazione: ${YELLOW}${WP_DIR}/wp-config.php${NC}"

=== Verifica ===

# Verifica chiavi di sicurezza
#grep -A1 "AUTH_KEY" ${WP_DIR}/wp-config.php

# Test backup database
#ls -lh /var/backups/wp_db_*.sql.gz

# Verifica cron jobs
#crontab -l
