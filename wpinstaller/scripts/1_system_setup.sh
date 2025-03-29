#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    1_system_setup.sh                                  :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Script di configurazione del sistema
# Questo script si occupa di preparare il sistema per l'installazione di WordPress:
# - Aggiorna il sistema
# - Installa i pacchetti necessari
# - Configura Nginx
# - Configura PHP
# - Crea le directory necessarie

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
LOG_FILE="${LOGS_DIR}/system_setup.log"
mkdir -p "${LOGS_DIR}"
chmod 750 "${LOGS_DIR}"

# ============================================================================== #
# SEZIONE: Configurazione trap per gestione errori
# ============================================================================== #

# Configura trap per gestire gli errori
# Questa funzione viene chiamata automaticamente quando si verifica un errore
trap 'handle_error ${LINENO} "1_system_setup.sh" "${LOG_FILE}"' ERR

# ============================================================================== #
# SEZIONE: Funzioni di configurazione del sistema
# ============================================================================== #

# Funzione: Aggiorna il sistema
# Aggiorna gli indici dei pacchetti e installa gli aggiornamenti disponibili
update_system() {
    log "STEP" "Aggiornamento sistema" "${LOG_FILE}"
    
    # Verifica connessione internet
    check_internet_connection "${LOG_FILE}" || {
        log "ERROR" "Connessione internet non disponibile" "${LOG_FILE}"
        return 1
    }
    
    # Aggiorna gli indici dei pacchetti
    log "INFO" "Aggiornamento indici pacchetti..." "${LOG_FILE}"
    apt-get update -qq || {
        log "ERROR" "Impossibile aggiornare gli indici dei pacchetti" "${LOG_FILE}"
        return 1
    }
    
    # Aggiorna i pacchetti installati (solo se non siamo in WSL)
    if ! detect_wsl "${LOG_FILE}"; then
        log "INFO" "Aggiornamento pacchetti installati..." "${LOG_FILE}"
        apt-get upgrade -y -qq || {
            log "WARNING" "Impossibile aggiornare alcuni pacchetti, continuo comunque" "${LOG_FILE}"
        }
    else
        log "INFO" "Ambiente WSL rilevato, salto l'aggiornamento dei pacchetti" "${LOG_FILE}"
    fi
    
    log "SUCCESS" "Sistema aggiornato" "${LOG_FILE}"
    return 0
}

# Funzione: Installa i pacchetti necessari
# Installa tutti i pacchetti richiesti per WordPress, Nginx, PHP e MySQL
install_packages() {
    log "STEP" "Installazione pacchetti" "${LOG_FILE}"
    
    # Verifica se saltare l'installazione dei pacchetti
    if [[ "${SKIP_PACKAGE_INSTALL:-false}" == "true" ]]; then
        log "INFO" "Installazione pacchetti saltata come richiesto" "${LOG_FILE}"
        return 0
    }
    
    # Rileva la versione PHP disponibile
    detect_php_version "${LOG_FILE}"
    
    # Lista dei pacchetti da installare
    local packages=(
        # Nginx
        "nginx"
        
        # MySQL/MariaDB
        "mariadb-server"
        "mariadb-client"
        
        # PHP e moduli
        "php${PHP_VERSION}"
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-mysql"
        "php${PHP_VERSION}-curl"
        "php${PHP_VERSION}-gd"
        "php${PHP_VERSION}-intl"
        "php${PHP_VERSION}-mbstring"
        "php${PHP_VERSION}-soap"
        "php${PHP_VERSION}-xml"
        "php${PHP_VERSION}-zip"
        "php${PHP_VERSION}-cli"
        
        # Strumenti
        "curl"
        "unzip"
        "git"
    )
    
    # Installa i pacchetti
    log "INFO" "Installazione pacchetti..." "${LOG_FILE}"
    apt-get install -y -qq "${packages[@]}" || {
        log "ERROR" "Impossibile installare i pacchetti richiesti" "${LOG_FILE}"
        return 1
    }
    
    # Installa WP-CLI
    install_wp_cli
    
    log "SUCCESS" "Pacchetti installati correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Installa WP-CLI
# Installa WordPress Command Line Interface
install_wp_cli() {
    log "INFO" "Installazione WP-CLI..." "${LOG_FILE}"
    
    # Verifica se WP-CLI è già installato
    if command -v wp &> /dev/null; then
        log "INFO" "WP-CLI già installato" "${LOG_FILE}"
        return 0
    fi
    
    # Scarica WP-CLI
    curl -s -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar || {
        log "ERROR" "Impossibile scaricare WP-CLI" "${LOG_FILE}"
        return 1
    }
    
    # Verifica il file scaricato
    php /tmp/wp-cli.phar --info &> /dev/null || {
        log "ERROR" "File WP-CLI scaricato non valido" "${LOG_FILE}"
        return 1
    }
    
    # Rendi eseguibile e sposta in /usr/local/bin
    chmod +x /tmp/wp-cli.phar
    mv /tmp/wp-cli.phar /usr/local/bin/wp
    
    # Verifica l'installazione
    if ! command -v wp &> /dev/null; then
        log "ERROR" "Installazione WP-CLI fallita" "${LOG_FILE}"
        return 1
    fi
    
    log "SUCCESS" "WP-CLI installato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Configura Nginx
# Configura il server web Nginx per WordPress
configure_nginx() {
    log "STEP" "Configurazione Nginx" "${LOG_FILE}"
    
    # Verifica se Nginx è installato
    if ! command -v nginx &> /dev/null; then
        log "ERROR" "Nginx non installato" "${LOG_FILE}"
        return 1
    }
    
    # Crea directory per i siti
    log "INFO" "Creazione directory per i siti..." "${LOG_FILE}"
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled
    
    # Verifica se la configurazione di default esiste
    if [[ -f "/etc/nginx/sites-enabled/default" ]]; then
        log "INFO" "Disabilitazione configurazione default..." "${LOG_FILE}"
        rm -f /etc/nginx/sites-enabled/default
    fi
    
    # Crea configurazione WordPress
    log "INFO" "Creazione configurazione WordPress..." "${LOG_FILE}"
    
    # Seleziona il template appropriato
    local template
    if [[ "${ENV_MODE}" == "prod" ]]; then
        template="${ROOT_DIR}/templates/nginx-prod.conf"
    else
        template="${ROOT_DIR}/templates/nginx-local.conf"
    fi
    
    # Verifica esistenza template
    if [[ ! -f "${template}" ]]; then
        log "ERROR" "Template Nginx non trovato: ${template}" "${LOG_FILE}"
        return 1
    }
    
    # Prepara variabili per sostituzione
    local vars=(
        "SERVER_PORT=${SERVER_PORT}"
        "DOMAIN=${DOMAIN}"
        "WP_DIR=${WP_DIR}"
        "PHP_VERSION=${PHP_VERSION}"
    )
    
    # Applica template
    replace_in_template "${template}" "/etc/nginx/sites-available/wordpress" "${LOG_FILE}" "${vars[@]}" || {
        log "ERROR" "Impossibile applicare template Nginx" "${LOG_FILE}"
        return 1
    }
    
    # Abilita il sito
    log "INFO" "Abilitazione sito WordPress..." "${LOG_FILE}"
    ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress
    
    # Verifica configurazione Nginx
    log "INFO" "Verifica configurazione Nginx..." "${LOG_FILE}"
    nginx -t &> /dev/null || {
        log "ERROR" "Configurazione Nginx non valida" "${LOG_FILE}"
        return 1
    }
    
    # Riavvia Nginx
    log "INFO" "Riavvio Nginx..." "${LOG_FILE}"
    restart_service "nginx" "${LOG_FILE}" || {
        log "ERROR" "Impossibile riavviare Nginx" "${LOG_FILE}"
        return 1
    }
    
    log "SUCCESS" "Nginx configurato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Configura PHP
# Configura PHP per WordPress
configure_php() {
    log "STEP" "Configurazione PHP" "${LOG_FILE}"
    
    # Verifica se PHP è installato
    if ! command -v php &> /dev/null; then
        log "ERROR" "PHP non installato" "${LOG_FILE}"
        return 1
    }
    
    # Percorso file configurazione PHP
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    
    # Verifica esistenza file
    if [[ ! -f "${php_ini}" ]]; then
        log "ERROR" "File configurazione PHP non trovato: ${php_ini}" "${LOG_FILE}"
        return 1
    }
    
    # Backup file originale
    backup_file "${php_ini}" "${LOG_FILE}"
    
    # Modifica configurazione PHP
    log "INFO" "Modifica configurazione PHP..." "${LOG_FILE}"
    
    # Impostazioni da modificare
    local settings=(
        "upload_max_filesize = 64M"
        "post_max_size = 64M"
        "memory_limit = 256M"
        "max_execution_time = 300"
        "max_input_time = 300"
        "display_errors = Off"
    )
    
    # Abilita display_errors in modalità debug
    if [[ "${WP_DEBUG}" == "true" ]]; then
        settings[5]="display_errors = On"
    fi
    
    # Applica le impostazioni
    for setting in "${settings[@]}"; do
        local name=$(echo "${setting}" | cut -d= -f1 | xargs)
        local value=$(echo "${setting}" | cut -d= -f2- | xargs)
        
        # Verifica se l'impostazione esiste
        if grep -q "^${name}" "${php_ini}"; then
            # Modifica l'impostazione esistente
            sed -i "s|^${name}.*|${name} = ${value}|" "${php_ini}"
        else
            # Aggiungi l'impostazione
            echo "${name} = ${value}" >> "${php_ini}"
        fi
    done
    
    # Riavvia PHP-FPM
    log "INFO" "Riavvio PHP-FPM..." "${LOG_FILE}"
    restart_service "php${PHP_VERSION}-fpm" "${LOG_FILE}" || {
        log "ERROR" "Impossibile riavviare PHP-FPM" "${LOG_FILE}"
        return 1
    }
    
    log "SUCCESS" "PHP configurato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Crea directory WordPress
# Crea la directory per l'installazione di WordPress
create_wordpress_directory() {
    log "STEP" "Creazione directory WordPress" "${LOG_FILE}"
    
    # Crea la directory se non esiste
    if [[ ! -d "${WP_DIR}" ]]; then
        log "INFO" "Creazione directory ${WP_DIR}..." "${LOG_FILE}"
        mkdir -p "${WP_DIR}"
    else
        log "INFO" "Directory ${WP_DIR} già esistente" "${LOG_FILE}"
    fi
    
    # Imposta proprietario e permessi
    log "INFO" "Impostazione proprietario e permessi..." "${LOG_FILE}"
    chown -R "${WP_UID}":"${WP_GID}" "${WP_DIR}"
    chmod -R "${DIR_PERMS}" "${WP_DIR}"
    
    log "SUCCESS" "Directory WordPress creata correttamente" "${LOG_FILE}"
    return 0
}

# ============================================================================== #
# SEZIONE: Funzione principale
# ============================================================================== #

# Funzione: Main
# Funzione principale che gestisce il flusso del programma
main() {
    log "STEP" "Inizio configurazione sistema" "${LOG_FILE}"
    
    # Inizializza ambiente
    init_environment
    
    # Carica configurazione
    if [[ -f "${CONFIG_DIR}/config.cfg" ]]; then
        source "${CONFIG_DIR}/config.cfg"
    else
        log "ERROR" "File di configurazione non trovato" "${LOG_FILE}"
        exit 1
    }
    
    # Rileva ambiente
    init_environment_detection
    
    # Verifica se la configurazione del sistema è già stata completata
    if check_installation_status "system_setup"; then
        log "INFO" "Configurazione sistema già completata" "${LOG_FILE}"
        
        # Chiedi all'utente se vuole riconfigurare
        if [[ "${INTERACTIVE:-true}" == "true" ]]; then
            echo -e "\n${YELLOW}La configurazione del sistema è già stata completata.${NC}"
            echo -n "Vuoi riconfigurare? [s/N]: "
            read -r response
            
            if [[ ! "${response}" =~ ^[Ss]$ ]]; then
                log "INFO" "Riconfigurazione sistema saltata su richiesta dell'utente" "${LOG_FILE}"
                exit 0
            fi
        else
            log "INFO" "Modalità non interattiva, salto la riconfigurazione" "${LOG_FILE}"
            exit 0
        fi
    fi
    
    # Aggiorna il sistema
    update_system || {
        log "ERROR" "Aggiornamento sistema fallito" "${LOG_FILE}"
        exit 1
    }
    
    # Installa i pacchetti necessari
    install_packages || {
        log "ERROR" "Installazione pacchetti fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Configura Nginx
    configure_nginx || {
        log "ERROR" "Configurazione Nginx fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Configura PHP
    configure_php || {
        log "ERROR" "Configurazione PHP fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Crea directory WordPress
    create_wordpress_directory || {
        log "ERROR" "Creazione directory WordPress fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Imposta stato installazione
    set_installation_status "system_setup"
    
    log "SUCCESS" "Configurazione sistema completata con successo" "${LOG_FILE}"
    
    # Mostra informazioni di riepilogo
    echo -e "\n${BOLD}CONFIGURAZIONE SISTEMA COMPLETATA${NC}"
    echo -e "Sistema operativo: ${DISTRO_NAME} ${DISTRO_VERSION}"
    echo -e "WSL: $(detect_wsl "${LOG_FILE}" && echo "Sì" || echo "No")"
    echo -e "PHP: ${PHP_VERSION}"
    echo -e "Directory WordPress: ${WP_DIR}"
    echo -e "Log: ${LOG_FILE}"
    echo ""
    
    exit 0
}

# ============================================================================== #
# SEZIONE: Esecuzione principale
# ============================================================================== #

# Esegui la funzione principale
main
