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

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Ottimizzazione PHP con controllo versione
optimize_php() {
    echo -e "\033[1;33m⚡ Ottimizzazione PHP-FPM...\033[0m"
    
    local php_conf="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    [ -f "$php_conf" ] || { echo -e "\033[0;31m❌ File config PHP non trovato!\033[0m"; exit 1; }
    
    # Backup configurazione originale
    cp "$php_conf" "${php_conf}.bak"
    
    # Applicazione impostazioni ottimizzate
    sed -i "s/^pm = .*/pm = dynamic/" "$php_conf"
    sed -i "s/^pm.max_children = .*/pm.max_children = 25/" "$php_conf"
    sed -i "s/^pm.start_servers = .*/pm.start_servers = 5/" "$php_conf"
    sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = 3/" "$php_conf"
    sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = 10/" "$php_conf"
    
    systemctl restart php${PHP_VERSION}-fpm || {
        echo -e "\033[0;31m❌ Riavvio PHP-FPM fallito! Ripristino backup...\033[0m"
        mv "${php_conf}.bak" "$php_conf"
        systemctl restart php${PHP_VERSION}-fpm
        exit 1
    }
}

# Configurazione WordPress con generazione chiavi sicure
configure_wp() {
    echo -e "\033[1;33m🔧 Configurazione WordPress...\033[0m"
    
    # Verifica esistenza directory WP
    [ -d "${WP_DIR}" ] || { echo -e "\033[0;31m❌ Directory WordPress non trovata!\033[0m"; exit 1; }
    
    # Generazione chiavi con fallback
    local auth_key=$(openssl rand -base64 48 2>/dev/null || head /dev/urandom | tr -dc A-Za-z0-9 | head -c48)
    # ... (genera tutte le chiavi simili)
    
    # Creazione wp-config.php con verifica
    cp "${WP_DIR}/wp-config-sample.php" "${WP_DIR}/wp-config.php" || {
        echo -e "\033[0;31m❌ File config WordPress non trovato!\033[0m"
        exit 1
    }
    
    # Inserimento chiavi nel file
    sed -i "s/define( 'AUTH_KEY',         'put your unique phrase here' );/define( 'AUTH_KEY',         '${auth_key}' );/" "${WP_DIR}/wp-config.php"
    # ... (applica tutte le sostituzioni)
}

echo -e "\033[1;36m🚀 Configurazione finale...\033[0m"
validate_config
optimize_php
configure_wp

echo -e "\033[0;32m✅ Ottimizzazioni completate\033[0m"