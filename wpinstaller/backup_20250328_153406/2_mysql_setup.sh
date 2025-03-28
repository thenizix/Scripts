#!/bin/bash
# CONFIGURAZIONE SICURA MYSQL

source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/mysql_setup.log"

# Funzione: Riparazione emergenza
emergency_repair() {
    echo "Riparazione database in corso..." | tee -a "$LOG_FILE"
    sudo rm -rf /var/lib/mysql/*
    sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    sudo chown -R mysql:mysql /var/lib/mysql
}

# Main process
{
    echo "=== CONFIGURAZIONE DATABASE ==="
    
    # Verifica installazione MariaDB
    if ! dpkg -l mariadb-server >/dev/null; then
        echo -e "\033[0;31m[ERRORE] MariaDB non installato\033[0m" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # Riprova avvio servizio
    for attempt in {1..3}; do
        if manage_service "mariadb" "start"; then
            # Configurazione sicura
            sudo mysql -uroot <<SQL
                ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
                DELETE FROM mysql.user WHERE User='';
                DROP DATABASE IF EXISTS test;
                CREATE DATABASE ${MYSQL_WP_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
                GRANT ALL ON ${MYSQL_WP_DB}.* TO '${MYSQL_WP_USER}'@'localhost' IDENTIFIED BY '${MYSQL_WP_PASS}';
                FLUSH PRIVILEGES;
SQL
            break
        else
            emergency_repair
        fi
    done
    
    # Verifica finale
    mysql -u"${MYSQL_WP_USER}" -p"${MYSQL_WP_PASS}" -e "USE ${MYSQL_WP_DB};" || exit 1
    
    echo "=== DATABASE CONFIGURATO ==="
} 2>&1 | tee -a "$LOG_FILE"
