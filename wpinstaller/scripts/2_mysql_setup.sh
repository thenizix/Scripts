#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    2_mysql_setup.sh                                   :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Script di configurazione del database MySQL/MariaDB
# Questo script si occupa di:
# - Configurare MySQL/MariaDB in modo sicuro
# - Creare il database per WordPress
# - Creare l'utente per WordPress
# - Impostare i permessi corretti
# - Salvare le credenziali in modo sicuro

# ============================================================================== #
# SEZIONE: Impostazioni di sicurezza per bash
# ============================================================================== #
# Queste impostazioni rendono lo script più robusto e sicuro

# set -e: Termina lo script se un comando restituisce un codice di errore
# set -u: Termina lo script se viene utilizzata una variabile non definita
# set -o pipefail: Considera fallito un pipeline se uno qualsiasi dei comandi fallisce
set -euo pipefail

# ============================================================================== #
# SEZIONE: Inizializzazione percorsi e variabili
# ============================================================================== #

# Percorso assoluto della directory dello script
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Percorso della directory principale (root) del progetto
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

# Percorsi delle sottodirectory principali
CONFIG_DIR="${ROOT_DIR}/config"       # Directory configurazione
LOGS_DIR="${ROOT_DIR}/logs"           # Directory log
STATE_DIR="${ROOT_DIR}/state"         # Directory stato

# Carica librerie comuni
source "${SCRIPT_DIR}/lib/common.sh"

# File di log
LOG_FILE="${LOGS_DIR}/mysql_setup.log"
mkdir -p "${LOGS_DIR}"
chmod 750 "${LOGS_DIR}"

# ============================================================================== #
# SEZIONE: Configurazione trap per gestione errori
# ============================================================================== #

# Configura trap per gestire gli errori
# Questa funzione viene chiamata automaticamente quando si verifica un errore
trap 'handle_error ${LINENO} "2_mysql_setup.sh" "${LOG_FILE}"' ERR

# ============================================================================== #
# SEZIONE: Funzioni di configurazione MySQL
# ============================================================================== #

# Funzione: Verifica se MySQL è in esecuzione
# Controlla se il servizio MySQL/MariaDB è attivo
check_mysql_running() {
    log "INFO" "Verifica stato MySQL/MariaDB..." "${LOG_FILE}"
    
    # Verifica se il servizio è attivo
    if check_service_status "mysql" "${LOG_FILE}" || check_service_status "mariadb" "${LOG_FILE}"; then
        log "SUCCESS" "MySQL/MariaDB è in esecuzione" "${LOG_FILE}"
        return 0
    fi
    
    # Se non è attivo, prova ad avviarlo
    log "WARNING" "MySQL/MariaDB non è in esecuzione, tentativo di avvio..." "${LOG_FILE}"
    
    # Prova ad avviare MySQL
    if start_service "mysql" "${LOG_FILE}" || start_service "mariadb" "${LOG_FILE}"; then
        log "SUCCESS" "MySQL/MariaDB avviato correttamente" "${LOG_FILE}"
        return 0
    fi
    
    log "ERROR" "Impossibile avviare MySQL/MariaDB" "${LOG_FILE}"
    return 1
}

# Funzione: Configura MySQL in modo sicuro
# Esegue una configurazione sicura di MySQL/MariaDB
secure_mysql_installation() {
    log "STEP" "Configurazione sicura MySQL/MariaDB" "${LOG_FILE}"
    
    # Verifica se MySQL è in esecuzione
    check_mysql_running || {
        log "ERROR" "MySQL/MariaDB non è in esecuzione" "${LOG_FILE}"
        return 1
    }
    
    # Genera password root se non esiste
    if [[ -z "${MYSQL_ROOT_PASS:-}" ]]; then
        MYSQL_ROOT_PASS=$(generate_secure_password 16 "${LOG_FILE}")
        log "INFO" "Password root MySQL generata" "${LOG_FILE}"
    fi
    
    # Verifica se MySQL è già stato configurato
    if mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SELECT 1" &>/dev/null; then
        log "INFO" "MySQL/MariaDB già configurato con password root" "${LOG_FILE}"
    else
        # Configura MySQL in modo sicuro
        log "INFO" "Configurazione sicura MySQL/MariaDB..." "${LOG_FILE}"
        
        # Verifica se è possibile accedere senza password
        if mysql -u root -e "SELECT 1" &>/dev/null; then
            log "INFO" "Accesso root senza password possibile, impostazione password..." "${LOG_FILE}"
            
            # Imposta password root
            mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOF
        else
            log "ERROR" "Impossibile accedere a MySQL/MariaDB" "${LOG_FILE}"
            return 1
        fi
    fi
    
    # Esegui configurazione sicura
    log "INFO" "Applicazione configurazione sicura..." "${LOG_FILE}"
    
    # Rimuovi utenti anonimi
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
DELETE FROM mysql.user WHERE User='';
EOF
    
    # Rimuovi accesso remoto per root
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
EOF
    
    # Rimuovi database di test
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
EOF
    
    # Applica i cambiamenti
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
FLUSH PRIVILEGES;
EOF
    
    # Salva password root in modo sicuro
    log "INFO" "Salvataggio credenziali root MySQL..." "${LOG_FILE}"
    
    # Crea directory sicura per le credenziali
    create_secure_credentials_dir "${CREDS_DIR}" "${LOG_FILE}"
    
    # Salva credenziali
    save_credentials "${MYSQL_CREDS_FILE}" "${LOG_FILE}" "MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS}"
    
    log "SUCCESS" "MySQL/MariaDB configurato in modo sicuro" "${LOG_FILE}"
    return 0
}

# Funzione: Crea database WordPress
# Crea il database per WordPress
create_wordpress_database() {
    log "STEP" "Creazione database WordPress" "${LOG_FILE}"
    
    # Verifica se MySQL è in esecuzione
    check_mysql_running || {
        log "ERROR" "MySQL/MariaDB non è in esecuzione" "${LOG_FILE}"
        return 1
    }
    
    # Carica credenziali root
    if [[ -f "${MYSQL_CREDS_FILE}" ]]; then
        load_credentials "${MYSQL_CREDS_FILE}" "${LOG_FILE}" || {
            log "ERROR" "Impossibile caricare credenziali MySQL" "${LOG_FILE}"
            return 1
        }
    else
        log "ERROR" "File credenziali MySQL non trovato" "${LOG_FILE}"
        return 1
    }
    
    # Genera nome database se non esiste
    if [[ -z "${MYSQL_WP_DB:-}" ]]; then
        MYSQL_WP_DB="wordpress"
        log "INFO" "Nome database WordPress: ${MYSQL_WP_DB}" "${LOG_FILE}"
    fi
    
    # Verifica se il database esiste già
    if mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SHOW DATABASES LIKE '${MYSQL_WP_DB}'" | grep -q "${MYSQL_WP_DB}"; then
        log "INFO" "Database ${MYSQL_WP_DB} già esistente" "${LOG_FILE}"
    else
        # Crea database
        log "INFO" "Creazione database ${MYSQL_WP_DB}..." "${LOG_FILE}"
        mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE ${MYSQL_WP_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
    fi
    
    log "SUCCESS" "Database WordPress creato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Crea utente WordPress
# Crea l'utente per WordPress e imposta i permessi
create_wordpress_user() {
    log "STEP" "Creazione utente WordPress" "${LOG_FILE}"
    
    # Verifica se MySQL è in esecuzione
    check_mysql_running || {
        log "ERROR" "MySQL/MariaDB non è in esecuzione" "${LOG_FILE}"
        return 1
    }
    
    # Carica credenziali root
    if [[ -f "${MYSQL_CREDS_FILE}" ]]; then
        load_credentials "${MYSQL_CREDS_FILE}" "${LOG_FILE}" || {
            log "ERROR" "Impossibile caricare credenziali MySQL" "${LOG_FILE}"
            return 1
        }
    else
        log "ERROR" "File credenziali MySQL non trovato" "${LOG_FILE}"
        return 1
    }
    
    # Genera nome utente se non esiste
    if [[ -z "${MYSQL_WP_USER:-}" ]]; then
        MYSQL_WP_USER="wpuser"
        log "INFO" "Nome utente WordPress: ${MYSQL_WP_USER}" "${LOG_FILE}"
    fi
    
    # Genera password utente se non esiste
    if [[ -z "${MYSQL_WP_PASS:-}" ]]; then
        MYSQL_WP_PASS=$(generate_secure_password 16 "${LOG_FILE}")
        log "INFO" "Password utente WordPress generata" "${LOG_FILE}"
    fi
    
    # Verifica se l'utente esiste già
    if mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SELECT User FROM mysql.user WHERE User='${MYSQL_WP_USER}'" | grep -q "${MYSQL_WP_USER}"; then
        log "INFO" "Utente ${MYSQL_WP_USER} già esistente, aggiornamento password..." "${LOG_FILE}"
        
        # Aggiorna password
        mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
ALTER USER '${MYSQL_WP_USER}'@'localhost' IDENTIFIED BY '${MYSQL_WP_PASS}';
FLUSH PRIVILEGES;
EOF
    else
        # Crea utente
        log "INFO" "Creazione utente ${MYSQL_WP_USER}..." "${LOG_FILE}"
        mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE USER '${MYSQL_WP_USER}'@'localhost' IDENTIFIED BY '${MYSQL_WP_PASS}';
EOF
    fi
    
    # Imposta permessi
    log "INFO" "Impostazione permessi per ${MYSQL_WP_USER}..." "${LOG_FILE}"
    mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF
GRANT ALL PRIVILEGES ON ${MYSQL_WP_DB}.* TO '${MYSQL_WP_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    # Salva credenziali WordPress
    log "INFO" "Salvataggio credenziali utente WordPress..." "${LOG_FILE}"
    
    # Aggiorna file credenziali MySQL
    save_credentials "${MYSQL_CREDS_FILE}" "${LOG_FILE}" \
        "MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS}" \
        "MYSQL_WP_DB=${MYSQL_WP_DB}" \
        "MYSQL_WP_USER=${MYSQL_WP_USER}" \
        "MYSQL_WP_PASS=${MYSQL_WP_PASS}"
    
    log "SUCCESS" "Utente WordPress creato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Verifica connessione database
# Verifica che sia possibile connettersi al database con le credenziali WordPress
verify_database_connection() {
    log "STEP" "Verifica connessione database" "${LOG_FILE}"
    
    # Verifica se MySQL è in esecuzione
    check_mysql_running || {
        log "ERROR" "MySQL/MariaDB non è in esecuzione" "${LOG_FILE}"
        return 1
    }
    
    # Carica credenziali
    if [[ -f "${MYSQL_CREDS_FILE}" ]]; then
        load_credentials "${MYSQL_CREDS_FILE}" "${LOG_FILE}" || {
            log "ERROR" "Impossibile caricare credenziali MySQL" "${LOG_FILE}"
            return 1
        }
    else
        log "ERROR" "File credenziali MySQL non trovato" "${LOG_FILE}"
        return 1
    }
    
    # Verifica connessione
    log "INFO" "Verifica connessione al database ${MYSQL_WP_DB}..." "${LOG_FILE}"
    if mysql -u "${MYSQL_WP_USER}" -p"${MYSQL_WP_PASS}" -e "USE ${MYSQL_WP_DB}; SELECT 1" &>/dev/null; then
        log "SUCCESS" "Connessione al database verificata" "${LOG_FILE}"
        return 0
    else
        log "ERROR" "Impossibile connettersi al database" "${LOG_FILE}"
        return 1
    fi
}

# ============================================================================== #
# SEZIONE: Funzione principale
# ============================================================================== #

# Funzione: Main
# Funzione principale che gestisce il flusso del programma
main() {
    log "STEP" "Inizio configurazione MySQL/MariaDB" "${LOG_FILE}"
    
    # Inizializza ambiente
    init_environment
    
    # Carica configurazione
    if [[ -f "${CONFIG_DIR}/config.cfg" ]]; then
        source "${CONFIG_DIR}/config.cfg"
    else
        log "ERROR" "File di configurazione non trovato" "${LOG_FILE}"
        exit 1
    }
    
    # Verifica se la configurazione del sistema è stata completata
    if ! check_installation_status "system_setup"; then
        log "ERROR" "Configurazione sistema non completata" "${LOG_FILE}"
        echo -e "\n${RED}La configurazione del sistema non è stata completata.${NC}"
        echo -e "${RED}Eseguire prima lo script 1_system_setup.sh${NC}"
        exit 1
    fi
    
    # Verifica se la configurazione del database è già stata completata
    if check_installation_status "mysql_setup"; then
        log "INFO" "Configurazione database già completata" "${LOG_FILE}"
        
        # Chiedi all'utente se vuole riconfigurare
        if [[ "${INTERACTIVE:-true}" == "true" ]]; then
            echo -e "\n${YELLOW}La configurazione del database è già stata completata.${NC}"
            echo -n "Vuoi riconfigurare? [s/N]: "
            read -r response
            
            if [[ ! "${response}" =~ ^[Ss]$ ]]; then
                log "INFO" "Riconfigurazione database saltata su richiesta dell'utente" "${LOG_FILE}"
                exit 0
            fi
        else
            # In modalità non interattiva, salta se richiesto
            if [[ "${SKIP_DB_SETUP:-false}" == "true" ]]; then
                log "INFO" "Configurazione database saltata come richiesto" "${LOG_FILE}"
                exit 0
            fi
        fi
    fi
    
    # Configura MySQL in modo sicuro
    secure_mysql_installation || {
        log "ERROR" "Configurazione sicura MySQL fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Crea database WordPress
    create_wordpress_database || {
        log "ERROR" "Creazione database WordPress fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Crea utente WordPress
    create_wordpress_user || {
        log "ERROR" "Creazione utente WordPress fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Verifica connessione database
    verify_database_connection || {
        log "ERROR" "Verifica connessione database fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Imposta stato installazione
    set_installation_status "mysql_setup"
    
    log "SUCCESS" "Configurazione MySQL/MariaDB completata con successo" "${LOG_FILE}"
    
    # Mostra informazioni di riepilogo
    echo -e "\n${BOLD}CONFIGURAZIONE DATABASE COMPLETATA${NC}"
    echo -e "Database: ${MYSQL_WP_DB}"
    echo -e "Utente: ${MYSQL_WP_USER}"
    echo -e "Password: ${MYSQL_WP_PASS}"
    echo -e "File credenziali: ${MYSQL_CREDS_FILE}"
    echo -e "Log: ${LOG_FILE}"
    echo ""
    
    exit 0
}

# ============================================================================== #
# SEZIONE: Esecuzione principale
# ============================================================================== #

# Esegui la funzione principale
main
