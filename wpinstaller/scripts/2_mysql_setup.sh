#!/bin/bash
# wpinstaller/scripts/2_mysql_setup.sh
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

# Funzione: Configurazione sicura MySQL
secure_mysql_installation() {
    echo "🔐 Configurazione sicura MariaDB..." | tee -a "$LOG_FILE"
    
    # Comandi SQL in blocco per evitare injection
    mysql -u root <<-SQL
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
    if check_mysql_connection "root" "${MYSQL_ROOT_PASS}"; then
        echo "✅ Credenziali root verificate" | tee -a "$LOG_FILE"
    else
        exit 1
    fi
    
    if check_mysql_connection "${MYSQL_WP_USER}" "${MYSQL_WP_PASS}"; then
        echo "✅ Credenziali WP verificate" | tee -a "$LOG_FILE"
    else
        exit 1
    fi
}

# Main Process
{
    echo "=== CONFIGURAZIONE DATABASE ===" | tee -a "$LOG_FILE"
    
    # 1. Verifica installazione MariaDB
    if ! dpkg -l mariadb-server &>/dev/null; then
        echo "❌ MariaDB non installato" | tee -a "$LOG_FILE"
        apt-get install -y mariadb-server || exit 1
    fi

    # 2. Avvio servizio con tentativi multipli
    for attempt in {1..3}; do
        echo "🔄 Tentativo $attempt di avvio MariaDB..." | tee -a "$LOG_FILE"
        if ${SERVICE_CMD} mysql start; then
            # Attesa connessione
            for i in {1..10}; do
                if mysqladmin ping --silent 2>/dev/null; then
                    echo "✅ MariaDB avviato correttamente" | tee -a "$LOG_FILE"
                    break 2
                fi
                sleep 2
                echo "⏳ Attesa avvio MariaDB ($i/10)..." | tee -a "$LOG_FILE"
            done
        fi
        echo "⚠️ Fallito tentativo $attempt" | tee -a "$LOG_FILE"
        sleep 5
    done

    # 3. Verifica se root ha già password
    if mysql -u root -e "SELECT 1" &>/dev/null; then
        echo "⚠️ MySQL accessibile senza password" | tee -a "$LOG_FILE"
        secure_mysql_installation
    elif mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SELECT 1" &>/dev/null; then
        echo "ℹ️ MySQL già configurato con password" | tee -a "$LOG_FILE"
        
        # Verifica esistenza database e utente
        if ! mysql -u root -p"${MYSQL_ROOT_PASS}" -e "USE \`${MYSQL_WP_DB}\`" &>/dev/null; then
            echo "🔧 Creazione database ${MYSQL_WP_DB}" | tee -a "$LOG_FILE"
            mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS \`${MYSQL_WP_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        fi
        
        # Crea/aggiorna utente WordPress
        echo "🔧 Configurazione utente ${MYSQL_WP_USER}" | tee -a "$LOG_FILE"
        mysql -u root -p"${MYSQL_ROOT_PASS}" <<-SQL
            CREATE USER IF NOT EXISTS '${MYSQL_WP_USER}'@'localhost' IDENTIFIED BY '${MYSQL_WP_PASS}';
            GRANT ALL PRIVILEGES ON \`${MYSQL_WP_DB}\`.* TO '${MYSQL_WP_USER}'@'localhost';
            FLUSH PRIVILEGES;
SQL
    else
        secure_mysql_installation
    fi

    # 4. Test finale accesso con utente WordPress
    echo "🔍 Test finale accesso database..." | tee -a "$LOG_FILE"
    if mysql -u "${MYSQL_WP_USER}" -p"${MYSQL_WP_PASS}" -e "SHOW TABLES FROM \`${MYSQL_WP_DB}\`;" &>/dev/null; then
        echo "✅ Database configurato correttamente!" | tee -a "$LOG_FILE"
        echo "   Database: ${MYSQL_WP_DB}" | tee -a "$LOG_FILE"
        echo "   Utente: ${MYSQL_WP_USER}" | tee -a "$LOG_FILE"
    else
        echo "❌ Test finale fallito" | tee -a "$LOG_FILE"
        exit 1
    fi
}