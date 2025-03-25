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

secure_mariadb() {
    echo -e "\033[1;33m🔐 Configurazione MariaDB...\033[0m"
    
    # Verifica se MariaDB è già configurato
    if mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SELECT 1" >/dev/null 2>&1; then
        echo -e "\033[0;32m✔ MariaDB già configurato\033[0m"
        return 0
    fi
    
    # Configurazione iniziale solo se necessario
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

    # Verifica finale
    if ! mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SELECT 1" >/dev/null 2>&1; then
        echo -e "\033[0;31m❌ Configurazione MariaDB fallita!\033[0m"
        return 1
    fi
}

setup_wp_database() {
    echo -e "\033[1;33m💾 Configurazione database WordPress...\033[0m"
    
    # Crea database se non esiste
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_WP_DB}\` 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MYSQL_WP_USER}'@'localhost' 
IDENTIFIED BY '${MYSQL_WP_PASS}';

GRANT ALL PRIVILEGES ON \`${MYSQL_WP_DB}\`.* 
TO '${MYSQL_WP_USER}'@'localhost';

FLUSH PRIVILEGES;
EOF

    # Verifica creazione
    if ! mysql -u root -p"${MYSQL_ROOT_PASS}" -e "USE ${MYSQL_WP_DB}" >/dev/null 2>&1; then
        echo -e "\033[0;31m❌ Creazione database fallita!\033[0m"
        return 1
    fi
}

# Main
echo -e "\033[1;36m🚀 Configurazione database...\033[0m"

secure_mariadb || exit 1
setup_wp_database || exit 1

echo -e "\033[0;32m✅ Configurazione database completata\033[0m"