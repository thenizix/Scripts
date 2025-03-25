#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    3_wordpress_setup.sh                              :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg

install_wordpress() {
    echo -e "\033[1;33m📥 Installazione WordPress...\033[0m"
    
    # Crea directory se non esiste
    mkdir -p "${WP_DIR}"
    
    # Scarica WordPress solo se necessario
    if [ ! -f "${WP_DIR}/wp-includes/version.php" ]; then
        echo -e "\033[1;34m⬇️ Download ultima versione WordPress...\033[0m"
        wget -q https://wordpress.org/latest.tar.gz -P /tmp || {
            echo -e "\033[0;31m❌ Download fallito!\033[0m"
            return 1
        }
        
        # Estrazione
        tar -xzf /tmp/latest.tar.gz -C /var/www/html || {
            echo -e "\033[0;31m❌ Estrazione fallita!\033[0m"
            return 1
        }
        
        # Pulizia
        rm -f /tmp/latest.tar.gz
    else
        echo -e "\033[0;32m✔ WordPress già installato\033[0m"
    fi
    
    # Configura permessi
    chown -R www-data:www-data "${WP_DIR}"
    find "${WP_DIR}" -type d -exec chmod 755 {} \;
    find "${WP_DIR}" -type f -exec chmod 644 {} \;
}

configure_wp_config() {
    echo -e "\033[1;33m🔧 Configurazione WordPress...\033[0m"
    
    # Crea wp-config.php solo se non esiste
    if [ ! -f "${WP_DIR}/wp-config.php" ]; then
        cp "${WP_DIR}/wp-config-sample.php" "${WP_DIR}/wp-config.php"
        
        # Genera chiavi di sicurezza
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
            local key=$(openssl rand -base64 48 | tr -d '\n=+/')
            sed -i "/${salt}/s/put your unique phrase here/${key}/" "${WP_DIR}/wp-config.php"
        done
        
        # Configura database
        sed -i "s/database_name_here/${MYSQL_WP_DB}/" "${WP_DIR}/wp-config.php"
        sed -i "s/username_here/${MYSQL_WP_USER}/" "${WP_DIR}/wp-config.php"
        sed -i "s/password_here/${MYSQL_WP_PASS}/" "${WP_DIR}/wp-config.php"
        
        # Hardening
        echo -e "\n/* Sicurezza aggiuntiva */" >> "${WP_DIR}/wp-config.php"
        echo "define('DISALLOW_FILE_EDIT', true);" >> "${WP_DIR}/wp-config.php"
        echo "define('FORCE_SSL_ADMIN', true);" >> "${WP_DIR}/wp-config.php"
        
        # Protezione file config
        chmod 600 "${WP_DIR}/wp-config.php"
    else
        echo -e "\033[0;32m✔ Configurazione già esistente\033[0m"
    fi
}

# Main
echo -e "\033[1;36m🚀 Installazione WordPress...\033[0m"

install_wordpress || exit 1
configure_wp_config || exit 1

echo -e "\033[0;32m✅ Installazione WordPress completata\033[0m"