#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    5_final_config.sh                                 :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg

optimize_php() {
    echo -e "\033[1;33m⚡ Ottimizzazione PHP-FPM...\033[0m"
    
    local php_conf="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    [ -f "$php_conf" ] || {
        echo -e "\033[0;31m❌ File config PHP non trovato per la versione ${PHP_VERSION}!\033[0m"
        exit 1
    }
    
    # Backup
    cp "$php_conf" "${php_conf}.bak"
    
    # Ottimizzazioni
    sed -i "s/^pm = .*/pm = dynamic/" "$php_conf"
    sed -i "s/^pm.max_children = .*/pm.max_children = 25/" "$php_conf"
    sed -i "s/^pm.start_servers = .*/pm.start_servers = 5/" "$php_conf"
    sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = 3/" "$php_conf"
    sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = 10/" "$php_conf"
    sed -i "s/^;pm.max_requests = .*/pm.max_requests = 500/" "$php_conf"
    
    # Impostazioni aggiuntive
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    sed -i "s/^memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" "$php_ini"
    sed -i "s/^max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION_TIME}/" "$php_ini"
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" "$php_ini"
    sed -i "s/^post_max_size = .*/post_max_size = ${PHP_POST_MAX_SIZE}/" "$php_ini"
    sed -i "s/^;opcache.enable=.*/opcache.enable=1/" "$php_ini"
    
    if ! systemctl restart php${PHP_VERSION}-fpm; then
        echo -e "\033[0;31m❌ Riavvio PHP-FPM fallito! Ripristino backup...\033[0m"
        mv "${php_conf}.bak" "$php_conf"
        exit 1
    fi
}

configure_wp() {
    echo -e "\033[1;33m🔧 Configurazione WordPress...\033[0m"
    
    [ -d "${WP_DIR}" ] || {
        echo -e "\033[0;31m❌ Directory WordPress non trovata in ${WP_DIR}!\033[0m"
        exit 1
    }
    
    # Generazione chiavi di sicurezza
    local salts=(
        AUTH_KEY
        SECURE_AUTH_KEY
        LOGGED_IN_KEY
        NONCE_KEY
        AUTH_SALT
        SECURE_AUTH_SALT
        LOGGED_IN_SALT
        NONCE_SALT
    )
    
    for salt in "${salts[@]}"; do
        local key=$(openssl rand -base64 48 2>/dev/null || head /dev/urandom | tr -dc A-Za-z0-9 | head -c64)
        sed -i "s/define( '${salt}',.*/define( '${salt}', '${key}' );/" "${WP_DIR}/wp-config.php"
    done
    
    # Configurazione database
    sed -i "s/database_name_here/${MYSQL_WP_DB}/" "${WP_DIR}/wp-config.php"
    sed -i "s/username_here/${MYSQL_WP_USER}/" "${WP_DIR}/wp-config.php"
    sed -i "s/password_here/${MYSQL_WP_PASS}/" "${WP_DIR}/wp-config.php"
    
    # Hardening aggiuntivo
    echo -e "\n/* Disabilita editor temi/plugin */\ndefine('DISALLOW_FILE_EDIT', true);" >> "${WP_DIR}/wp-config.php"
}

echo -e "\033[1;36m🚀 Configurazione finale...\033[0m"
validate_config
optimize_php
configure_wp

echo -e "\033[0;32m✅ Ottimizzazioni completate\033[0m"