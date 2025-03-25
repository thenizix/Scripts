#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    2_mysql_setup.sh                                   :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

# ****************************************************************************** #
#                                                                                #
#           CONFIGURAZIONE AVANZATA DATABASE MARIADB/MYSQL - WSL/Win             #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Funzione per configurare la sicurezza di MySQL
secure_mysql() {
    echo -e "\033[1;33m🔐 Configurazione sicurezza MySQL...\033[0m"
    
    # Primo tentativo con password vuota
    mysql -u root <<EOF 2>/dev/null || \
    # Secondo tentativo con password configurata
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    if [ $? -ne 0 ]; then
        echo -e "\033[0;31m❌ Configurazione fallita, reset completo MariaDB...\033[0m"
        systemctl stop mariadb
        rm -rf /var/lib/mysql/
        mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
        systemctl start mariadb
        secure_mysql  # Riprova
    fi
}

# Funzione per creare il database WordPress
setup_wp_database() {
    echo -e "\033[1;33m💾 Creazione database WordPress...\033[0m"
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_WP_DB} 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MYSQL_WP_USER}'@'localhost' 
IDENTIFIED BY '${MYSQL_WP_PASS}';

GRANT ALL PRIVILEGES ON ${MYSQL_WP_DB}.* 
TO '${MYSQL_WP_USER}'@'localhost';

FLUSH PRIVILEGES;
EOF

    # Verifica che il database sia stato creato
    if ! mysql -u root -p"${MYSQL_ROOT_PASS}" -e "USE ${MYSQL_WP_DB};" 2>/dev/null; then
        echo -e "\033[0;31m❌ Creazione database fallita!\033[0m"
        exit 1
    fi
}

# Main execution
echo -e "\033[1;36m🚀 Configurazione database...\033[0m"
validate_config
secure_mysql
setup_wp_database

echo -e "\033[0;32m✅ Database configurato correttamente\033[0m"