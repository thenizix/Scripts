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

install_wordpress_core() {
    echo -e "\033[1;33m📥 Download e installazione WordPress...\033[0m"
    
    # Crea directory se non esiste
    mkdir -p "${WP_DIR}"
    cd "${WP_DIR}" || return 1

    # Rimuovi eventuali installazioni incomplete
    rm -rf wp-admin wp-includes wp-content wp-*.php index.php license.txt readme.html
    
    # Scarica l'ultima versione
    if ! wget -q https://wordpress.org/latest.tar.gz; then
        echo -e "\033[0;31m❌ Download WordPress fallito!\033[0m"
        return 1
    fi
    
    # Estrai e pulisci
    if ! tar -xzf latest.tar.gz --strip-components=1; then
        echo -e "\033[0;31m❌ Estrazione archivio fallita!\033[0m"
        rm -f latest.tar.gz
        return 1
    fi
    rm -f latest.tar.gz
    
    # Verifica file essenziali
    if [ ! -f "wp-includes/version.php" ] || [ ! -f "wp-admin/includes/upgrade.php" ]; then
        echo -e "\033[0;31m❌ File core WordPress mancanti!\033[0m"
        return 1
    fi
    
    return 0
}

configure_wp_settings() {
    echo -e "\033[1;33m🔧 Configurazione WordPress...\033[0m"
    
    cd "${WP_DIR}" || return 1

    # Crea wp-config.php se non esiste o è vuoto
    if [ ! -f "wp-config.php" ] || [ ! -s "wp-config.php" ]; then
        if [ ! -f "wp-config-sample.php" ]; then
            echo -e "\033[0;31m❌ File wp-config-sample.php mancante!\033[0m"
            return 1
        fi
        
        cp wp-config-sample.php wp-config.php
        
        # Configurazione database con awk (più robusto di sed)
        awk -v dbname="${MYSQL_WP_DB}" \
            -v dbuser="${MYSQL_WP_USER}" \
            -v dbpass="${MYSQL_WP_PASS}" '
            /database_name_here/ { gsub("database_name_here", dbname) }
            /username_here/ { gsub("username_here", dbuser) }
            /password_here/ { gsub("password_here", dbpass) }
            { print }
        ' wp-config.php > wp-config.temp && mv wp-config.temp wp-config.php
        
        # Aggiungi impostazioni di sicurezza
        {
            echo ""
            echo "/* Impostazioni di sicurezza */"
            echo "define('DISALLOW_FILE_EDIT', true);"
            echo "define('FORCE_SSL_ADMIN', true);"
        } >> wp-config.php
        
        # Genera chiavi di sicurezza
        for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
            salt=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c 64)
            # Usa awk invece di sed per la sostituzione
            awk -v key="${key}" -v salt="${salt}" '
                $0 ~ key { 
                    sub(/put your unique phrase here/, salt) 
                }
                { print }
            ' wp-config.php > wp-config.temp && mv wp-config.temp wp-config.php
        done
    fi
    
    # Imposta permessi corretti
    chown -R www-data:www-data "${WP_DIR}"
    find "${WP_DIR}" -type d -exec chmod 755 {} \;
    find "${WP_DIR}" -type f -exec chmod 644 {} \;
    chmod 600 wp-config.php
    
    return 0
}

complete_wp_installation() {
    echo -e "\033[1;33m🚀 Completamento installazione...\033[0m"
    
    # Verifica se l'installazione è già completa
    if wp core is-installed --path="${WP_DIR}" 2>/dev/null; then
        echo -e "\033[0;32m✔ WordPress già installato\033[0m"
        return 0
    fi
    
    # Completa l'installazione via CLI se possibile
    if command -v wp &>/dev/null; then
        wp core install --path="${WP_DIR}" --url="http://${DOMAIN}" \
            --title="Sito WordPress" --admin_user="admin" \
            --admin_password="$(openssl rand -base64 12)" \
            --admin_email="${ADMIN_EMAIL}" --skip-email
    else
        echo -e "\033[1;35mℹ Completa l'installazione manualmente:\033[0m"
        echo -e "\033[1;36mhttp://${DOMAIN}/wp-admin/install.php\033[0m"
    fi
}

# Main
echo -e "\033[1;36m🚀 Installazione WordPress...\033[0m"

install_wordpress_core || exit 1
configure_wp_settings || exit 1
complete_wp_installation || exit 1

echo -e "\033[0;32m✅ Installazione WordPress completata con successo!\033[0m"