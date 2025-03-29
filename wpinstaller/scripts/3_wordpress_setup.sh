#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    3_wordpress_setup.sh                               :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Script di installazione WordPress
# Questo script si occupa di:
# - Scaricare WordPress
# - Configurare wp-config.php
# - Installare WordPress
# - Configurare i permessi
# - Installare plugin e temi (opzionale)

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
LOG_FILE="${LOGS_DIR}/wordpress_setup.log"
mkdir -p "${LOGS_DIR}"
chmod 750 "${LOGS_DIR}"

# ============================================================================== #
# SEZIONE: Configurazione trap per gestione errori
# ============================================================================== #

# Configura trap per gestire gli errori
# Questa funzione viene chiamata automaticamente quando si verifica un errore
trap 'handle_error ${LINENO} "3_wordpress_setup.sh" "${LOG_FILE}"' ERR

# ============================================================================== #
# SEZIONE: Funzioni di installazione WordPress
# ============================================================================== #

# Funzione: Scarica WordPress
# Scarica l'ultima versione di WordPress
download_wordpress() {
    log "STEP" "Download WordPress" "${LOG_FILE}"
    
    # Verifica se WordPress è già installato
    if [[ -f "${WP_DIR}/wp-config.php" ]]; then
        log "INFO" "WordPress già installato in ${WP_DIR}" "${LOG_FILE}"
        
        # Chiedi all'utente se vuole reinstallare
        if [[ "${INTERACTIVE:-true}" == "true" ]]; then
            echo -e "\n${YELLOW}WordPress è già installato in ${WP_DIR}.${NC}"
            echo -n "Vuoi reinstallare? [s/N]: "
            read -r response
            
            if [[ ! "${response}" =~ ^[Ss]$ ]]; then
                log "INFO" "Reinstallazione WordPress saltata su richiesta dell'utente" "${LOG_FILE}"
                return 0
            fi
        else
            log "INFO" "WordPress già installato, salto il download" "${LOG_FILE}"
            return 0
        fi
    fi
    
    # Verifica connessione internet
    check_internet_connection "${LOG_FILE}" || {
        log "ERROR" "Connessione internet non disponibile" "${LOG_FILE}"
        return 1
    }
    
    # Crea directory WordPress se non esiste
    if [[ ! -d "${WP_DIR}" ]]; then
        log "INFO" "Creazione directory ${WP_DIR}..." "${LOG_FILE}"
        mkdir -p "${WP_DIR}"
    fi
    
    # Verifica se WP-CLI è installato
    if ! command -v wp &> /dev/null; then
        log "ERROR" "WP-CLI non installato" "${LOG_FILE}"
        return 1
    fi
    
    # Scarica WordPress
    log "INFO" "Download WordPress..." "${LOG_FILE}"
    cd "${WP_DIR}"
    wp core download --locale=it_IT --allow-root || {
        log "ERROR" "Impossibile scaricare WordPress" "${LOG_FILE}"
        return 1
    }
    
    # Imposta proprietario e permessi
    log "INFO" "Impostazione proprietario e permessi..." "${LOG_FILE}"
    chown -R "${WP_UID}":"${WP_GID}" "${WP_DIR}"
    chmod -R "${DIR_PERMS}" "${WP_DIR}"
    
    log "SUCCESS" "WordPress scaricato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Configura WordPress
# Crea e configura il file wp-config.php
configure_wordpress() {
    log "STEP" "Configurazione WordPress" "${LOG_FILE}"
    
    # Verifica se WordPress è stato scaricato
    if [[ ! -f "${WP_DIR}/wp-load.php" ]]; then
        log "ERROR" "WordPress non trovato in ${WP_DIR}" "${LOG_FILE}"
        return 1
    }
    
    # Carica credenziali database
    if [[ -f "${MYSQL_CREDS_FILE}" ]]; then
        load_credentials "${MYSQL_CREDS_FILE}" "${LOG_FILE}" || {
            log "ERROR" "Impossibile caricare credenziali MySQL" "${LOG_FILE}"
            return 1
        }
    else
        log "ERROR" "File credenziali MySQL non trovato" "${LOG_FILE}"
        return 1
    }
    
    # Verifica se wp-config.php esiste già
    if [[ -f "${WP_DIR}/wp-config.php" ]]; then
        log "INFO" "File wp-config.php già esistente, creazione backup..." "${LOG_FILE}"
        backup_file "${WP_DIR}/wp-config.php" "${LOG_FILE}"
    fi
    
    # Genera salt per WordPress
    log "INFO" "Generazione salt WordPress..." "${LOG_FILE}"
    local wp_salts=$(generate_wordpress_salts "${LOG_FILE}")
    
    # Crea wp-config.php
    log "INFO" "Creazione wp-config.php..." "${LOG_FILE}"
    cd "${WP_DIR}"
    wp config create \
        --dbname="${MYSQL_WP_DB}" \
        --dbuser="${MYSQL_WP_USER}" \
        --dbpass="${MYSQL_WP_PASS}" \
        --dbhost="localhost" \
        --dbcharset="utf8mb4" \
        --dbcollate="utf8mb4_unicode_ci" \
        --locale="it_IT" \
        --allow-root || {
        log "ERROR" "Impossibile creare wp-config.php" "${LOG_FILE}"
        return 1
    }
    
    # Aggiungi salt personalizzati
    log "INFO" "Aggiunta salt personalizzati..." "${LOG_FILE}"
    sed -i "/define( 'AUTH_KEY'/,/define( 'NONCE_SALT'/d" "${WP_DIR}/wp-config.php"
    sed -i "/\$table_prefix/i ${wp_salts}" "${WP_DIR}/wp-config.php"
    
    # Aggiungi configurazione debug
    log "INFO" "Configurazione debug..." "${LOG_FILE}"
    if [[ "${WP_DEBUG}" == "true" ]]; then
        sed -i "/\$table_prefix/i define( 'WP_DEBUG', true );\ndefine( 'WP_DEBUG_LOG', true );\ndefine( 'WP_DEBUG_DISPLAY', true );" "${WP_DIR}/wp-config.php"
    else
        sed -i "/\$table_prefix/i define( 'WP_DEBUG', false );" "${WP_DIR}/wp-config.php"
    fi
    
    # Imposta permessi wp-config.php
    log "INFO" "Impostazione permessi wp-config.php..." "${LOG_FILE}"
    chown "${WP_UID}":"${WP_GID}" "${WP_DIR}/wp-config.php"
    chmod 600 "${WP_DIR}/wp-config.php"
    
    log "SUCCESS" "WordPress configurato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Installa WordPress
# Esegue l'installazione di WordPress
install_wordpress() {
    log "STEP" "Installazione WordPress" "${LOG_FILE}"
    
    # Verifica se WordPress è già installato
    if wp core is-installed --path="${WP_DIR}" --allow-root &>/dev/null; then
        log "INFO" "WordPress già installato" "${LOG_FILE}"
        
        # Chiedi all'utente se vuole reinstallare
        if [[ "${INTERACTIVE:-true}" == "true" ]]; then
            echo -e "\n${YELLOW}WordPress è già installato.${NC}"
            echo -n "Vuoi reinstallare? [s/N]: "
            read -r response
            
            if [[ ! "${response}" =~ ^[Ss]$ ]]; then
                log "INFO" "Reinstallazione WordPress saltata su richiesta dell'utente" "${LOG_FILE}"
                return 0
            fi
        else
            log "INFO" "WordPress già installato, salto l'installazione" "${LOG_FILE}"
            return 0
        fi
    fi
    
    # Genera credenziali amministratore WordPress
    if [[ -z "${WP_ADMIN_USER:-}" ]]; then
        WP_ADMIN_USER="admin"
        log "INFO" "Nome utente amministratore WordPress: ${WP_ADMIN_USER}" "${LOG_FILE}"
    fi
    
    if [[ -z "${WP_ADMIN_PASS:-}" ]]; then
        WP_ADMIN_PASS=$(generate_secure_password 12 "${LOG_FILE}")
        log "INFO" "Password amministratore WordPress generata" "${LOG_FILE}"
    fi
    
    if [[ -z "${WP_ADMIN_EMAIL:-}" ]]; then
        WP_ADMIN_EMAIL="${ADMIN_EMAIL}"
        log "INFO" "Email amministratore WordPress: ${WP_ADMIN_EMAIL}" "${LOG_FILE}"
    fi
    
    # Installa WordPress
    log "INFO" "Installazione WordPress..." "${LOG_FILE}"
    cd "${WP_DIR}"
    wp core install \
        --url="http://${DOMAIN}:${SERVER_PORT}" \
        --title="WordPress" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root || {
        log "ERROR" "Impossibile installare WordPress" "${LOG_FILE}"
        return 1
    }
    
    # Salva credenziali WordPress
    log "INFO" "Salvataggio credenziali WordPress..." "${LOG_FILE}"
    
    # Crea directory sicura per le credenziali
    create_secure_credentials_dir "${CREDS_DIR}" "${LOG_FILE}"
    
    # Salva credenziali
    save_credentials "${WP_CREDS_FILE}" "${LOG_FILE}" \
        "WP_ADMIN_USER=${WP_ADMIN_USER}" \
        "WP_ADMIN_PASS=${WP_ADMIN_PASS}" \
        "WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL}"
    
    log "SUCCESS" "WordPress installato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Configura permessi WordPress
# Imposta i permessi corretti per WordPress
configure_wordpress_permissions() {
    log "STEP" "Configurazione permessi WordPress" "${LOG_FILE}"
    
    # Verifica se WordPress è installato
    if [[ ! -d "${WP_DIR}" ]]; then
        log "ERROR" "Directory WordPress non trovata: ${WP_DIR}" "${LOG_FILE}"
        return 1
    fi
    
    # Applica hardening sicurezza
    apply_security_hardening "${WP_DIR}" "${WP_UID}" "${WP_GID}" "${LOG_FILE}" || {
        log "ERROR" "Impossibile applicare hardening sicurezza" "${LOG_FILE}"
        return 1
    }
    
    log "SUCCESS" "Permessi WordPress configurati correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Installa plugin WordPress
# Installa i plugin specificati nella configurazione
install_wordpress_plugins() {
    log "STEP" "Installazione plugin WordPress" "${LOG_FILE}"
    
    # Verifica se ci sono plugin da installare
    if [[ -z "${INSTALL_PLUGINS:-}" ]]; then
        log "INFO" "Nessun plugin da installare" "${LOG_FILE}"
        return 0
    fi
    
    # Verifica se WordPress è installato
    if ! wp core is-installed --path="${WP_DIR}" --allow-root &>/dev/null; then
        log "ERROR" "WordPress non installato" "${LOG_FILE}"
        return 1
    fi
    
    # Converti la stringa di plugin in array
    IFS=' ' read -ra plugins <<< "${INSTALL_PLUGINS}"
    
    # Installa ogni plugin
    for plugin in "${plugins[@]}"; do
        log "INFO" "Installazione plugin ${plugin}..." "${LOG_FILE}"
        cd "${WP_DIR}"
        wp plugin install "${plugin}" --activate --allow-root || {
            log "WARNING" "Impossibile installare plugin ${plugin}" "${LOG_FILE}"
            continue
        }
    done
    
    log "SUCCESS" "Plugin WordPress installati correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Installa tema WordPress
# Installa il tema specificato nella configurazione
install_wordpress_theme() {
    log "STEP" "Installazione tema WordPress" "${LOG_FILE}"
    
    # Verifica se c'è un tema da installare
    if [[ -z "${INSTALL_THEME:-}" ]]; then
        log "INFO" "Nessun tema da installare" "${LOG_FILE}"
        return 0
    fi
    
    # Verifica se WordPress è installato
    if ! wp core is-installed --path="${WP_DIR}" --allow-root &>/dev/null; then
        log "ERROR" "WordPress non installato" "${LOG_FILE}"
        return 1
    fi
    
    # Installa tema
    log "INFO" "Installazione tema ${INSTALL_THEME}..." "${LOG_FILE}"
    cd "${WP_DIR}"
    wp theme install "${INSTALL_THEME}" --activate --allow-root || {
        log "WARNING" "Impossibile installare tema ${INSTALL_THEME}" "${LOG_FILE}"
        return 1
    }
    
    log "SUCCESS" "Tema WordPress installato correttamente" "${LOG_FILE}"
    return 0
}

# ============================================================================== #
# SEZIONE: Funzione principale
# ============================================================================== #

# Funzione: Main
# Funzione principale che gestisce il flusso del programma
main() {
    log "STEP" "Inizio installazione WordPress" "${LOG_FILE}"
    
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
    
    # Verifica se la configurazione del database è stata completata
    if ! check_installation_status "mysql_setup"; then
        log "ERROR" "Configurazione database non completata" "${LOG_FILE}"
        echo -e "\n${RED}La configurazione del database non è stata completata.${NC}"
        echo -e "${RED}Eseguire prima lo script 2_mysql_setup.sh${NC}"
        exit 1
    fi
    
    # Verifica se l'installazione di WordPress è già stata completata
    if check_installation_status "wordpress_setup"; then
        log "INFO" "Installazione WordPress già completata" "${LOG_FILE}"
        
        # Chiedi all'utente se vuole reinstallare
        if [[ "${INTERACTIVE:-true}" == "true" ]]; then
            echo -e "\n${YELLOW}L'installazione di WordPress è già stata completata.${NC}"
            echo -n "Vuoi reinstallare? [s/N]: "
            read -r response
            
            if [[ ! "${response}" =~ ^[Ss]$ ]]; then
                log "INFO" "Reinstallazione WordPress saltata su richiesta dell'utente" "${LOG_FILE}"
                exit 0
            fi
        else
            # In modalità non interattiva, salta se richiesto
            if [[ "${SKIP_WP_INSTALL:-false}" == "true" ]]; then
                log "INFO" "Installazione WordPress saltata come richiesto" "${LOG_FILE}"
                exit 0
            fi
        fi
    fi
    
    # Scarica WordPress
    download_wordpress || {
        log "ERROR" "Download WordPress fallito" "${LOG_FILE}"
        exit 1
    }
    
    # Configura WordPress
    configure_wordpress || {
        log "ERROR" "Configurazione WordPress fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Installa WordPress
    install_wordpress || {
        log "ERROR" "Installazione WordPress fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Configura permessi WordPress
    configure_wordpress_permissions || {
        log "ERROR" "Configurazione permessi WordPress fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Installa plugin WordPress
    install_wordpress_plugins || {
        log "WARNING" "Installazione plugin WordPress fallita" "${LOG_FILE}"
        # Continua comunque, non è critico
    }
    
    # Installa tema WordPress
    install_wordpress_theme || {
        log "WARNING" "Installazione tema WordPress fallita" "${LOG_FILE}"
        # Continua comunque, non è critico
    }
    
    # Imposta stato installazione
    set_installation_status "wordpress_setup"
    
    log "SUCCESS" "Installazione WordPress completata con successo" "${LOG_FILE}"
    
    # Carica credenziali WordPress
    if [[ -f "${WP_CREDS_FILE}" ]]; then
        load_credentials "${WP_CREDS_FILE}" "${LOG_FILE}"
    fi
    
    # Mostra informazioni di riepilogo
    echo -e "\n${BOLD}INSTALLAZIONE WORDPRESS COMPLETATA${NC}"
    echo -e "URL: http://${DOMAIN}:${SERVER_PORT}"
    echo -e "Utente: ${WP_ADMIN_USER}"
    echo -e "Password: ${WP_ADMIN_PASS}"
    echo -e "Email: ${WP_ADMIN_EMAIL}"
    echo -e "Directory: ${WP_DIR}"
    echo -e "File credenziali: ${WP_CREDS_FILE}"
    echo -e "Log: ${LOG_FILE}"
    echo ""
    
    exit 0
}

# ============================================================================== #
# SEZIONE: Esecuzione principale
# ============================================================================== #

# Esegui la funzione principale
main
