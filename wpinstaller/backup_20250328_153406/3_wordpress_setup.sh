#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    3_wordpress_setup.sh                              :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@student.42.fr>          +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/06/01 17:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/06/11 10:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# ============================================================================== #
# INIZIALIZZAZIONE
# ============================================================================== #
set -eo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/wp_install.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================================== #
# FUNZIONI DI SUPPORTO
# ============================================================================== #

installa_wp_cli() {
    if ! command -v wp &> /dev/null; then
        echo "📥 Download WP-CLI..."
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        sudo mv wp-cli.phar /usr/local/bin/wp
    fi
}

# ============================================================================== #
# INSTALLAZIONE WORDPRESS
# ============================================================================== #
{
    echo "🚀 Inizio installazione WordPress"
    
    # Preparazione ambiente
    sudo rm -rf "${WP_DIR}"
    sudo mkdir -p "${WP_DIR}"
    sudo chown -R www-data:www-data "${WP_DIR}"
    
    # Installazione WP-CLI
    installa_wp_cli
    
    # Download WordPress
    sudo -u www-data wp core download \
        --locale=it_IT \
        --path="${WP_DIR}" \
        --force
        
    # Configurazione database
    sudo -u www-data wp config create \
        --dbname="${MYSQL_WP_DB}" \
        --dbuser="${MYSQL_WP_USER}" \
        --dbpass="${MYSQL_WP_PASS}" \
        --path="${WP_DIR}"
        
    # Installazione core
    admin_pass=$(openssl rand -base64 12)
    sudo -u www-data wp core install \
        --url="${DOMAIN}" \
        --title="Sito WordPress" \
        --admin_user="admin" \
        --admin_password="${admin_pass}" \
        --admin_email="${ADMIN_EMAIL}" \
        --path="${WP_DIR}"
        
    # Hardening sicurezza
    sudo find "${WP_DIR}" -type d -exec chmod 755 {} \;
    sudo find "${WP_DIR}" -type f -exec chmod 644 {} \;
    sudo chmod 640 "${WP_DIR}/wp-config.php"
    sudo -u www-data wp config set DISALLOW_FILE_EDIT true --raw --path="${WP_DIR}"
    
    echo "✅ WordPress installato correttamente!"
    echo "   URL Admin: http://${DOMAIN}/wp-admin"
    echo "   Username: admin"
    echo "   Password: ${admin_pass}"
} 2>&1 | tee -a "$LOG_FILE"
