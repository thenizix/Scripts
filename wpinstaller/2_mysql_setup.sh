#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    2_mysql_setup.sh                                  :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg

secure_mysql() {
    echo -e "\033[1;33m🔐 Configurazione sicurezza MySQL...\033[0m"
    
    # 1. Tentativo con password vuota
    if ! mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';" 2>/dev/null; then
        
        # 2. Reset completo se fallisce
        echo -e "\033[0;31m❌ Reset completo MariaDB...\033[0m"
        systemctl stop mariadb
        rm -rf /var/lib/mysql/*
        mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
        chown -R mysql:mysql /var/lib/mysql
        systemctl start mariadb
        
        # 3. Automazione completa di mysql_secure_installation
        mysql_secure_installation <<EOF
n
y
${MYSQL_ROOT_PASS}
${MYSQL_ROOT_PASS}
y
y
y
y
y
EOF
    fi

    # 4. Verifica finale
    if ! mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SHOW DATABASES;" 2>/dev/null; then
        echo -e "\033[0;31m❌ Configurazione fallita nonostante i tentativi!\033[0m"
        exit 1
    fi
}

setup_wp_database() {
    echo -e "\033[1;33m💾 Creazione database WordPress...\033[0m"
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_WP_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_WP_USER}'@'localhost' IDENTIFIED BY '${MYSQL_WP_PASS}';
GRANT ALL PRIVILEGES ON ${MYSQL_WP_DB}.* TO '${MYSQL_WP_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
}

echo -e "\033[1;36m🚀 Configurazione database...\033[0m"
validate_config
secure_mysql
setup_wp_database

echo -e "\033[0;32m✅ Database configurato correttamente\033[0m"