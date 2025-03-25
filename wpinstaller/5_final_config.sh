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
    echo -e "\033[1;33m⚡ Ottimizzazione PHP...\033[0m"
    
    local php_conf="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    
    # Backup configurazioni
    [ -f "$php_conf" ] && cp "$php_conf" "${php_conf}.bak"
    [ -f "$php_ini" ] && cp "$php_ini" "${php_ini}.bak"
    
    # Configurazione pool PHP-FPM
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
EOF
    
    # Configurazione PHP
    cat > "$php_ini" <<EOF
[PHP]
memory_limit = ${PHP_MEMORY_LIMIT}
max_execution_time = ${PHP_MAX_EXECUTION_TIME}
upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}
post_max_size = ${PHP_POST_MAX_SIZE}

[OPcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
EOF
    
    # Riavvio PHP-FPM
    systemctl restart php${PHP_VERSION}-fpm
}

# Main
echo -e "\033[1;36m🚀 Configurazione finale...\033[0m"

optimize_php || exit 1

echo -e "\033[0;32m✅ Ottimizzazione completata\033[0m"