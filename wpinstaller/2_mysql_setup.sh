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

# ============================================================================== #
#                          CONFIGURAZIONE DATABASE MARIADB/MYSQL                 #
# ============================================================================== #
# Questo script si occupa di:
# 1. Configurare la sicurezza di base di MariaDB
# 2. Creare il database WordPress
# 3. Configurare l'utente WordPress con i permessi
# ============================================================================== #

# Caricamento configurazioni condivise
source $(dirname "$0")/wp_installer.cfg

# ============================================================================== #
#                          IMPOSTAZIONI COLORI E FUNZIONI                        #
# ============================================================================== #
RED='\033[0;31m'    # Colore per errori
GREEN='\033[0;32m'  # Colore per successi
YELLOW='\033[1;33m' # Colore per avvisi
NC='\033[0m'        # Reset colore

# Funzione per eseguire query MySQL con doppio tentativo (con e senza password)
_execute_mysql() {
    local query="$1"
    mysql -u root -p"$MYSQL_ROOT_PASS" -e "$query" 2>/dev/null || mysql -u root -e "$query" 2>/dev/null
}

# Funzione per verificare l'esito dei comandi
_check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FALLITO${NC}"
        exit 1
    fi
}

# ============================================================================== #
#                          CONFIGURAZIONE SICUREZZA MYSQL                        #
# ============================================================================== #
echo -e "${YELLOW}[1/2] Configurazione sicurezza MariaDB...${NC}"

echo -n "Impostazione password root... "
_execute_mysql "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
_check

echo -n "Rimozione utenti anonimi... "
_execute_mysql "DELETE FROM mysql.user WHERE User='';"
_check

echo -n "Rimozione database di test... "
_execute_mysql "DROP DATABASE IF EXISTS test;"
_check

echo -n "Rimozione accessi root remoti... "
_execute_mysql "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
_check

echo -n "Applicazione modifiche... "
_execute_mysql "FLUSH PRIVILEGES;"
_check

# ============================================================================== #
#                          CREAZIONE DATABASE WORDPRESS                          #
# ============================================================================== #
echo -e "${YELLOW}\n[2/2] Configurazione database WordPress...${NC}"

echo -n "Creazione database... "
_execute_mysql "CREATE DATABASE IF NOT EXISTS $MYSQL_WP_DB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
_check

echo -n "Creazione utente WordPress... "
_execute_mysql "CREATE USER IF NOT EXISTS '$MYSQL_WP_USER'@'localhost' IDENTIFIED BY '$MYSQL_WP_PASS';"
_check

echo -n "Assegnazione permessi... "
_execute_mysql "GRANT ALL PRIVILEGES ON $MYSQL_WP_DB.* TO '$MYSQL_WP_USER'@'localhost';"
_check

echo -n "Applicazione modifiche... "
_execute_mysql "FLUSH PRIVILEGES;"
_check

# ============================================================================== #
#                          VERIFICA CONFIGURAZIONE                               #
# ============================================================================== #
echo -e "${YELLOW}\nVerifica finale configurazione...${NC}"

echo -n "Connessione al database... "
_execute_mysql "SHOW DATABASES;" | grep -q "$MYSQL_WP_DB"
_check

echo -n "Verifica utente WordPress... "
_execute_mysql "SELECT User FROM mysql.user;" | grep -q "$MYSQL_WP_USER"
_check

# ============================================================================== #
#                          FINE SCRIPT                                           #
# ============================================================================== #
echo -e "${GREEN}\nFase 2 completata con successo!${NC}"
echo -e "Procedi con l'esecuzione di: ${YELLOW}./3_wordpress_setup.sh${NC}"

# test manuale :   mysql -u $MYSQL_WP_USER -p$MYSQL_WP_PASS -e "SHOW DATABASES;"