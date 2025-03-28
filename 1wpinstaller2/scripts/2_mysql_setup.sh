#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    2_mysql_setup.sh                                   :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.it          #
#                                                                                #
# ****************************************************************************** #

# Configurazioni
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR%/*}"
source "${PROJECT_ROOT}/config/wp_installer.cfg"

# Caricamento configurazioni
source "${CONFIG_DIR}/wp_installer.cfg" || {
    echo -e "\033[0;31m❌ Errore nel caricamento della configurazione\033[0m" >&2
    exit 1
}

# Verifica permessi root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[0;31m❌ Lo script deve essere eseguito come root!\033[0m" >&2
    exit 1
fi

# Funzioni
secure_mysql() {
    echo -e "\033[1;34mConfigurazione sicura di MySQL...\033[0m"
    
    # Crea un file temporaneo per le query SQL
    local temp_file=$(mktemp)
    
    cat > "$temp_file" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    if ! mysql -uroot < "$temp_file"; then
        echo -e "\033[0;31m❌ Errore nella configurazione sicura di MySQL\033[0m" >&2
        rm -f "$temp_file"
        exit 1
    fi
    
    rm -f "$temp_file"
}

setup_database() {
    echo -e "\033[1;34mCreazione database WordPress...\033[0m"
    
    local temp_file=$(mktemp)
    
    cat > "$temp_file" <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_WP_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_WP_USER}'@'localhost' IDENTIFIED BY '${MYSQL_WP_PASS}';
GRANT ALL PRIVILEGES ON ${MYSQL_WP_DB}.* TO '${MYSQL_WP_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    if ! mysql -uroot -p"${MYSQL_ROOT_PASS}" < "$temp_file"; then
        echo -e "\033[0;31m❌ Errore nella creazione del database WordPress\033[0m" >&2
        rm -f "$temp_file"
        exit 1
    fi
    
    rm -f "$temp_file"
}

save_credentials() {
    local cred_file="/root/mysql_credentials.txt"
    
    echo -e "=== Credenziali MySQL ===" > "$cred_file"
    echo -e "Root Password: ${MYSQL_ROOT_PASS}" >> "$cred_file"
    echo -e "\n=== Database WordPress ===" >> "$cred_file"
    echo -e "Database Name: ${MYSQL_WP_DB}" >> "$cred_file"
    echo -e "DB User: ${MYSQL_WP_USER}" >> "$cred_file"
    echo -e "DB Password: ${MYSQL_WP_PASS}" >> "$cred_file"
    
    chmod 600 "$cred_file"
    echo -e "\033[1;33m⚠ Credenziali salvate in ${cred_file}\033[0m"
}

main() {
    echo -e "\033[1;36m=== Configurazione MySQL ===\033[0m"
    
    # Verifica che MySQL sia attivo
    if ! systemctl is-active mariadb >/dev/null; then
        echo -e "\033[0;31m❌ MySQL/MariaDB non è attivo!\033[0m" >&2
        exit 1
    fi
    
    secure_mysql
    setup_database
    save_credentials
    
    echo -e "\033[0;32m✅ MySQL configurato correttamente!\033[0m"
}

main