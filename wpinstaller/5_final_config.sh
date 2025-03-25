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

# ****************************************************************************** #
#                                                                                #
#             OTTIMIZZAZIONI FINALI E HARDENING - WSL/Win                        #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Funzione per ottimizzare PHP-FPM
optimize_php() {
    echo -e "\033[1;33m⚡ Ottimizzazione PHP-FPM...\033[0m"
    
    cat > /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf <<EOF
[www]
user = www-data
group = www-data
listen = /run/php/php${PHP_VERSION}-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 25
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests = 500

php_admin_value[memory_limit] = ${PHP_MEMORY_LIMIT}
php_admin_value[max_execution_time] = ${PHP_MAX_EXECUTION_TIME}
php_admin_value[upload_max_filesize] = ${PHP_UPLOAD_MAX_FILESIZE}
php_admin_value[post_max_size] = ${PHP_POST_MAX_SIZE}
php_admin_value[expose_php] = off
php_admin_value[disable_functions] = exec,passthru,shell_exec,system
php_admin_flag[display_errors] = off
EOF

    systemctl restart php${PHP_VERSION}-fpm
}

# Funzione per configurare WordPress
configure_wp() {
    echo -e "\033[1;33m🔧 Configurazione WordPress...\033[0m"
    
    # Genera chiavi di sicurezza uniche
    local auth_key=$(openssl rand -base64 48)
    local secure_auth_key=$(openssl rand -base64 48)
    local logged_in_key=$(openssl rand -base64 48)
    local nonce_key=$(openssl rand -base64 48)
    local auth_salt=$(openssl rand -base64 48)
    local secure_auth_salt=$(openssl rand -base64 48)
    local logged_in_salt=$(openssl rand -base64 48)
    local nonce_salt=$(openssl rand -base64 48)

    # Crea wp-config.php
    cat > ${WP_DIR}/wp-config.php <<EOF
<?php
define('DB_NAME', '${MYSQL_WP_DB}');
define('DB_USER', '${MYSQL_WP_USER}');
define('DB_PASSWORD', '${MYSQL_WP_PASS}');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

/* Chiavi di sicurezza uniche */
define('AUTH_KEY',         '${auth_key}');
define('SECURE_AUTH_KEY',  '${secure_auth_key}');
define('LOGGED_IN_KEY',    '${logged_in_key}');
define('NONCE_KEY',        '${nonce_key}');
define('AUTH_SALT',        '${auth_salt}');
define('SECURE_AUTH_SALT', '${secure_auth_salt}');
define('LOGGED_IN_SALT',   '${logged_in_salt}');
define('NONCE_SALT',       '${nonce_salt}');

/* Impostazioni HTTPS */
define('WP_HOME', 'https://${DOMAIN}');
define('WP_SITEURL', 'https://${DOMAIN}');

/* Debug & Sicurezza */
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
define('DISALLOW_FILE_EDIT', true);
define('FORCE_SSL_ADMIN', true);

\$table_prefix = 'wp_';
if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOF

    # Protezione aggiuntiva
    touch ${WP_DIR}/.htaccess
    cat > ${WP_DIR}/.htaccess <<EOF
# Blocca accesso a file sensibili
<FilesMatch "^(wp-config\.php|xmlrpc\.php)">
    Require all denied
</FilesMatch>

# Disabilita directory listing
Options -Indexes

# Protezione anti-hotlinking
RewriteEngine On
RewriteCond %{HTTP_REFERER} !^$
RewriteCond %{HTTP_REFERER} !^https://${DOMAIN} [NC]
RewriteRule \.(jpg|jpeg|png|gif)$ - [NC,F,L]

# Compressione
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css application/javascript
</IfModule>
EOF
}

# Funzione per impostare i cron jobs
setup_cron() {
    echo -e "\033[1;33m⏰ Configurazione cron jobs...\033[0m"
    
    # Backup giornaliero del database
    (crontab -l 2>/dev/null; echo "0 2 * * * mysqldump -u ${MYSQL_WP_USER} -p'${MYSQL_WP_PASS}' ${MYSQL_WP_DB} | gzip > /var/backups/wp_db_$(date +\%Y\%m\%d).sql.gz") | crontab -
    
    # Pulizia settimanale
    (crontab -l 2>/dev/null; echo "0 3 * * 0 find ${WP_DIR}/wp-content/upgrade/ -type d -mtime +7 -exec rm -rf {} +") | crontab -
}

# Main execution
echo -e "\033[1;36m🚀 Configurazione finale...\033[0m"
validate_config
optimize_php
configure_wp
setup_cron

echo -e "\033[0;32m✅ Ottimizzazioni completate\033[0m"