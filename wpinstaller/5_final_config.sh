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

# Funzione per verificare l'installazione di WordPress
verify_wp_installation() {
    echo -e "\033[1;33m🔍 Verifica installazione WordPress...\033[0m"
    
    local wp_files=(
        "${WP_DIR}/index.php"
        "${WP_DIR}/wp-config.php"
        "${WP_DIR}/wp-includes/version.php"
        "${WP_DIR}/wp-admin/includes/upgrade.php"
    )
    
    for file in "${wp_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "\033[0;31m❌ File mancante: $file\033[0m"
            return 1
        fi
    done
    
    if ! wp core is-installed --path="${WP_DIR}" 2>/dev/null; then
        echo -e "\033[0;31m❌ WordPress non è stato installato correttamente\033[0m"
        return 1
    fi
    
    echo -e "\033[0;32m✔ Installazione WordPress verificata\033[0m"
    return 0
}

# Funzione per ottimizzare PHP-FPM
optimize_php_fpm() {
    echo -e "\033[1;33m⚡ Ottimizzazione PHP-FPM...\033[0m"
    
    local php_conf="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    
    # Backup delle configurazioni esistenti
    [ -f "$php_conf" ] && cp "$php_conf" "${php_conf}.bak"
    [ -f "$php_ini" ] && cp "$php_ini" "${php_ini}.bak"
    
    # Configurazione ottimizzata del pool PHP-FPM
    cat > "$php_conf" <<EOF
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
pm.process_idle_timeout = 10s
request_terminate_timeout = 300
EOF
    
    # Configurazione ottimizzata di PHP
    cat > "$php_ini" <<EOF
[PHP]
engine = On
expose_php = Off
max_execution_time = ${PHP_MAX_EXECUTION_TIME}
memory_limit = ${PHP_MEMORY_LIMIT}
upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}
post_max_size = ${PHP_POST_MAX_SIZE}
max_input_vars = 5000
max_file_uploads = 20
default_socket_timeout = 60

[OPcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
opcache.enable_cli=0

[Session]
session.gc_maxlifetime = 1440
session.cookie_secure = 1
session.cookie_httponly = 1
session.cookie_samesite = Lax
EOF
    
    # Riavvio PHP-FPM con verifica
    if ! systemctl restart php${PHP_VERSION}-fpm; then
        echo -e "\033[0;31m❌ Riavvio PHP-FPM fallito! Ripristino backup...\033[0m"
        [ -f "${php_conf}.bak" ] && mv "${php_conf}.bak" "$php_conf"
        [ -f "${php_ini}.bak" ] && mv "${php_ini}.bak" "$php_ini"
        systemctl restart php${PHP_VERSION}-fpm
        return 1
    fi
    
    echo -e "\033[0;32m✔ Configurazione PHP-FPM ottimizzata\033[0m"
    return 0
}

# Funzione per configurare i permessi
secure_wp_permissions() {
    echo -e "\033[1;33m🔒 Configurazione permessi...\033[0m"
    
    # Imposta i permessi base
    find "${WP_DIR}" -type d -exec chmod 755 {} \;
    find "${WP_DIR}" -type f -exec chmod 644 {} \;
    
    # Permessi speciali per file critici
    chmod 600 "${WP_DIR}/wp-config.php"
    chmod 640 "${WP_DIR}/.htaccess" 2>/dev/null
    
    # Proprietà dei file
    chown -R www-data:www-data "${WP_DIR}"
    
    # File di debug
    rm -f "${WP_DIR}/error_log" "${WP_DIR}/debug.log" 2>/dev/null
    
    echo -e "\033[0;32m✔ Permessi configurati correttamente\033[0m"
    return 0
}

# Funzione per abilitare le regole di sicurezza
enable_security_rules() {
    echo -e "\033[1;33m🛡️ Configurazione sicurezza...\033[0m"
    
    local htaccess="${WP_DIR}/.htaccess"
    
    # Crea/aggiorna il file .htaccess
    cat > "$htaccess" <<EOF
# Blocca l'accesso ai file sensibili
<FilesMatch "^(wp-config\.php|readme\.html|license\.txt|error_log|debug\.log)">
    Require all denied
</FilesMatch>

# Disabilita l'esecuzione PHP nelle uploads
<Directory "${WP_DIR}/wp-content/uploads">
    php_flag engine off
</Directory>

# Proteggi dalle inclusioni dirette
Options -Indexes -ExecCGI
ServerSignature Off

# Regole per WordPress
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    RewriteRule ^index\.php$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [L]
</IfModule>
EOF
    
    # Aggiungi ulteriori direttive di sicurezza a wp-config.php
    if grep -q "DISALLOW_FILE_EDIT" "${WP_DIR}/wp-config.php"; then
        sed -i "/DISALLOW_FILE_EDIT/s/define.*/define('DISALLOW_FILE_EDIT', true);/" "${WP_DIR}/wp-config.php"
    else
        echo -e "\n/* Sicurezza aggiuntiva */" >> "${WP_DIR}/wp-config.php"
        echo "define('DISALLOW_FILE_EDIT', true);" >> "${WP_DIR}/wp-config.php"
        echo "define('FORCE_SSL_ADMIN', true);" >> "${WP_DIR}/wp-config.php"
    fi
    
    echo -e "\033[0;32m✔ Regole di sicurezza applicate\033[0m"
    return 0
}

# Main
echo -e "\033[1;36m🚀 Configurazione finale del sistema...\033[0m"

verify_wp_installation || exit 1
optimize_php_fpm || exit 1
secure_wp_permissions || exit 1
enable_security_rules || exit 1

echo -e "\033[0;32m✅ Configurazione finale completata con successo!\033[0m"
echo -e "\033[1;33mℹ Il sito è ora accessibile all'indirizzo: http://${DOMAIN}\033[0m"