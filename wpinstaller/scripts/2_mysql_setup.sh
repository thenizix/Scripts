#!/bin/bash
# SCRIPT DI CONFIGURAZIONE MYSQL - GESTIONE CREDENZIALI SICURE

set -euo pipefail
trap 'echo "❌ Errore a linea $LINENO"; exit 1' ERR

# Caricamento configurazione
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/mysql_setup.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# Funzione: Verifica connessione MySQL
check_mysql_connection() {
    local user="$1"
    local pass="$2"
    if ! mysql -u"${user}" -p"${pass}" -e "SHOW DATABASES;" &>/dev/null; then
        echo "❌ Connessione fallita per ${user}" | tee -a "$LOG_FILE"
        return 1
    fi
    return 0
}

# Funzione: Configurazione sicura iniziale
secure_mysql_installation() {
    echo "🔐 Configurazione sicura MariaDB..." | tee -a "$LOG_FILE"
    
    # Comandi SQL in blocco per evitare injection
    mysql -uroot <<-SQL
        -- Rimozione utenti anonimi
        DELETE FROM mysql.user WHERE User='';
        
        -- Rimozione database di test
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        
        -- Ricrea utente root con password
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
        
        -- Crea database WordPress
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_WP_DB}\`
            CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        
        -- Crea utente dedicato con permessi ristretti
        CREATE USER IF NOT EXISTS '${MYSQL_WP_USER}'@'localhost'
            IDENTIFIED BY '${MYSQL_WP_PASS}';
        
        -- Assegna permessi solo al database WordPress
        GRANT ALL PRIVILEGES ON \`${MYSQL_WP_DB}\`.* 
            TO '${MYSQL_WP_USER}'@'localhost';
        
        -- Applica modifiche
        FLUSH PRIVILEGES;
SQL

    # Verifica finale
    echo "🔍 Verifica credenziali..." | tee -a "$LOG_FILE"
    check_mysql_connection "root" "${MYSQL_ROOT_PASS}" || exit 1
    check_mysql_connection "${MYSQL_WP_USER}" "${MYSQL_WP_PASS}" || exit 1
}

# Main Process
{
    echo "=== CONFIGURAZIONE DATABASE ===" | tee -a "$LOG_FILE"
    
    # 1. Verifica installazione MariaDB
    if ! dpkg -l mariadb-server >/dev/null; then
        echo "❌ MariaDB non installato" | tee -a "$LOG_FILE"
        exit 1
    fi

    # 2. Avvio servizio con tentativi multipli
    for attempt in {1..3}; do
        echo "🔄 Tentativo $attempt di avvio MariaDB..." | tee -a "$LOG_FILE"
        if sudo ${SERVICE_CMD} start mysql; then
            # Attesa connessione
            until mysqladmin ping -uroot --silent; do
                sleep 2
                echo "⏳ Attesa avvio MariaDB..." | tee -a "$LOG_FILE"
            done
            break
        else
            echo "⚠️ Fallito tentativo $attempt" | tee -a "$LOG_FILE"
            sleep 5
        fi
    done

    # 3. Applica configurazione sicura
    secure_mysql_installation

    # 4. Verifica finale
    echo "🔍 Test operazioni database..." | tee -a "$LOG_FILE"
    mysql -u"${MYSQL_WP_USER}" -p"${MYSQL_WP_PASS}" -e "
        CREATE TABLE IF NOT EXISTS \`${MYSQL_WP_DB}\`.test_creds (
            id INT AUTO_INCREMENT PRIMARY KEY,
            test_value VARCHAR(100)
        ENGINE=InnoDB;
        DROP TABLE \`${MYSQL_WP_DB}\`.test_creds;" || {
        echo "❌ Test database fallito" | tee -a "$LOG_FILE"
        exit 1
    }

    echo "✅ Database configurato correttamente!" | tee -a "$LOG_FILE"
    echo "   Database: ${MYSQL_WP_DB}" | tee -a "$LOG_FILE"
    echo "   Utente: ${MYSQL_WP_USER}" | tee -a "$LOG_FILE"
}