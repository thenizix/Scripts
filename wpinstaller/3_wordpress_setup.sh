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

# Function to verify database connection
verify_db_connection() {
    local max_retries=5
    local retry_delay=5
    local attempt=0

    echo -e "\033[1;33m🔍 Verifying database connection...\033[0m"

    until [ $attempt -ge $max_retries ]; do
        if mysql -u "${MYSQL_WP_USER}" -p"${MYSQL_WP_PASS}" -h localhost -e "USE ${MYSQL_WP_DB};" 2>/dev/null; then
            echo -e "\033[0;32m✔ Database connection successful\033[0m"
            return 0
        fi
        attempt=$((attempt+1))
        echo -e "\033[1;33m⚠ Attempt ${attempt}/${max_retries}: Database not ready, retrying in ${retry_delay}s...\033[0m"
        sleep $retry_delay
    done

    echo -e "\033[0;31m❌ Failed to connect to database after ${max_retries} attempts\033[0m"
    return 1
}

install_wordpress_core() {
    echo -e "\033[1;33m📥 Downloading and installing WordPress...\033[0m"
    
    mkdir -p "${WP_DIR}"
    cd "${WP_DIR}" || return 1

    # Clean any previous installation
    rm -rf wp-admin wp-includes wp-content wp-*.php index.php license.txt readme.html
    
    # Download latest WordPress
    if ! wget -q https://wordpress.org/latest.tar.gz; then
        echo -e "\033[0;31m❌ WordPress download failed!\033[0m"
        return 1
    fi
    
    # Extract and clean up
    if ! tar -xzf latest.tar.gz --strip-components=1; then
        echo -e "\033[0;31m❌ Archive extraction failed!\033[0m"
        rm -f latest.tar.gz
        return 1
    fi
    rm -f latest.tar.gz
    
    # Verify core files
    if [ ! -f "wp-includes/version.php" ] || [ ! -f "wp-admin/includes/upgrade.php" ]; then
        echo -e "\033[0;31m❌ Missing WordPress core files!\033[0m"
        return 1
    fi
    
    return 0
}

configure_wp_settings() {
    echo -e "\033[1;33m🔧 Configuring WordPress...\033[0m"
    
    cd "${WP_DIR}" || return 1

    # Create wp-config.php if missing
    if [ ! -f "wp-config.php" ] || [ ! -s "wp-config.php" ]; then
        if [ ! -f "wp-config-sample.php" ]; then
            echo -e "\033[0;31m❌ Missing wp-config-sample.php!\033[0m"
            return 1
        fi
        
        # Use awk for safe configuration
        awk -v dbname="${MYSQL_WP_DB}" \
            -v dbuser="${MYSQL_WP_USER}" \
            -v dbpass="${MYSQL_WP_PASS}" \
            -v dbhost="localhost" \
            -v dbcharset="utf8mb4" \
            -v dbcollate="utf8mb4_unicode_ci" '
        /database_name_here/ { gsub("database_name_here", dbname) }
        /username_here/ { gsub("username_here", dbuser) }
        /password_here/ { gsub("password_here", dbpass) }
        /localhost/ { gsub("localhost", dbhost) }
        /utf8(_general_ci)?/ { 
            gsub("utf8(_general_ci)?", dbcharset)
            if ($0 ~ /define.*DB_CHARSET/) {
                print
                next
            }
        }
        /utf8_general_ci/ { gsub("utf8_general_ci", dbcollate) }
        { print }
        ' wp-config-sample.php > wp-config.php
        
        # Add security settings
        {
            echo ""
            echo "/* Security Settings */"
            echo "define('DISALLOW_FILE_EDIT', true);"
            echo "define('FORCE_SSL_ADMIN', true);"
            echo "define('WP_DEBUG', false);"
            echo "define('WP_AUTO_UPDATE_CORE', true);"
        } >> wp-config.php

        # Generate secure keys
        for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
            salt=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c 64)
            awk -v key="${key}" -v salt="${salt}" '
                $0 ~ key { 
                    sub(/put your unique phrase here/, salt) 
                }
                { print }
            ' wp-config.php > wp-config.tmp && mv wp-config.tmp wp-config.php
        done
    fi
    
    # Set proper permissions
    chown -R www-data:www-data "${WP_DIR}"
    find "${WP_DIR}" -type d -exec chmod 755 {} \;
    find "${WP_DIR}" -type f -exec chmod 644 {} \;
    chmod 600 wp-config.php
    
    return 0
}

complete_wp_installation() {
    echo -e "\033[1;33m🚀 Completing WordPress installation...\033[0m"
    
    # Verify if already installed
    if wp core is-installed --path="${WP_DIR}" 2>/dev/null; then
        echo -e "\033[0;32m✔ WordPress already installed\033[0m"
        return 0
    fi

    # Verify database connection first
    verify_db_connection || return 1

    # Generate random admin password
    ADMIN_PASS=$(openssl rand -base64 12)
    
    # Install via WP-CLI if available
    if command -v wp &>/dev/null; then
        wp core install --path="${WP_DIR}" \
            --url="http://${DOMAIN}" \
            --title="My WordPress Site" \
            --admin_user="admin" \
            --admin_password="${ADMIN_PASS}" \
            --admin_email="${ADMIN_EMAIL}" \
            --skip-email
            
        if [ $? -eq 0 ]; then
            echo -e "\033[0;32m✔ WordPress installed successfully\033[0m"
            echo -e "\033[1;33m🔑 Admin password: ${ADMIN_PASS}\033[0m"
            return 0
        else
            echo -e "\033[0;31m❌ WP-CLI installation failed\033[0m"
        fi
    fi

    # Fallback to manual installation
    echo -e "\033[1;35mℹ Complete installation manually:\033[0m"
    echo -e "\033[1;36mhttp://${DOMAIN}/wp-admin/install.php\033[0m"
    return 1
}

# Main execution
echo -e "\033[1;36m🚀 Starting WordPress installation...\033[0m"

if ! install_wordpress_core; then
    echo -e "\033[0;31m❌ Core installation failed!\033[0m"
    exit 1
fi

if ! configure_wp_settings; then
    echo -e "\033[0;31m❌ Configuration failed!\033[0m"
    exit 1
fi

if ! complete_wp_installation; then
    echo -e "\033[0;31m❌ Installation not completed automatically\033[0m"
    echo -e "\033[1;33mℹ Please complete the installation manually at:\033[0m"
    echo -e "\033[1;36mhttp://${DOMAIN}/wp-admin/install.php\033[0m"
    exit 1
fi

echo -e "\033[0;32m✅ WordPress installation completed successfully!\033[0m"
exit 0