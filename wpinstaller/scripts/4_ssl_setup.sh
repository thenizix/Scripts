#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    4_ssl_setup.sh                                     :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Script di configurazione SSL per WordPress
# Questo script si occupa di:
# - Generare certificati SSL (self-signed o Let's Encrypt)
# - Configurare Nginx per HTTPS
# - Aggiornare la configurazione di WordPress per HTTPS
# - Gestire i reindirizzamenti HTTP -> HTTPS

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
LOG_FILE="${LOGS_DIR}/ssl_setup.log"
mkdir -p "${LOGS_DIR}"
chmod 750 "${LOGS_DIR}"

# ============================================================================== #
# SEZIONE: Configurazione trap per gestione errori
# ============================================================================== #

# Configura trap per gestire gli errori
# Questa funzione viene chiamata automaticamente quando si verifica un errore
trap 'handle_error ${LINENO} "4_ssl_setup.sh" "${LOG_FILE}"' ERR

# ============================================================================== #
# SEZIONE: Funzioni di configurazione SSL
# ============================================================================== #

# Funzione: Verifica prerequisiti SSL
# Controlla che tutti i prerequisiti per SSL siano soddisfatti
check_ssl_prerequisites() {
    log "STEP" "Verifica prerequisiti SSL" "${LOG_FILE}"
    
    # Verifica se Nginx è installato
    if ! command -v nginx &> /dev/null; then
        log "ERROR" "Nginx non installato" "${LOG_FILE}"
        return 1
    fi
    
    # Verifica se OpenSSL è installato (per certificati self-signed)
    if [[ "${SSL_TYPE}" == "selfsigned" ]] && ! command -v openssl &> /dev/null; then
        log "ERROR" "OpenSSL non installato" "${LOG_FILE}"
        return 1
    fi
    
    # Verifica se Certbot è installato (per Let's Encrypt)
    if [[ "${SSL_TYPE}" == "letsencrypt" ]]; then
        if ! command -v certbot &> /dev/null; then
            log "INFO" "Certbot non installato, installazione in corso..." "${LOG_FILE}"
            
            # Installa Certbot
            apt-get update -qq
            apt-get install -y -qq certbot python3-certbot-nginx || {
                log "ERROR" "Impossibile installare Certbot" "${LOG_FILE}"
                return 1
            }
        fi
    fi
    
    # Verifica se WordPress è installato
    if ! wp core is-installed --path="${WP_DIR}" --allow-root &>/dev/null; then
        log "ERROR" "WordPress non installato" "${LOG_FILE}"
        return 1
    }
    
    log "SUCCESS" "Tutti i prerequisiti SSL soddisfatti" "${LOG_FILE}"
    return 0
}

# Funzione: Genera certificato self-signed
# Crea un certificato SSL self-signed
generate_selfsigned_certificate() {
    log "STEP" "Generazione certificato self-signed" "${LOG_FILE}"
    
    # Directory per i certificati
    local ssl_dir="/etc/nginx/ssl"
    
    # Crea directory se non esiste
    if [[ ! -d "${ssl_dir}" ]]; then
        log "INFO" "Creazione directory ${ssl_dir}..." "${LOG_FILE}"
        mkdir -p "${ssl_dir}"
        chmod 700 "${ssl_dir}"
    fi
    
    # Percorsi dei file certificato e chiave
    local cert_file="${ssl_dir}/${DOMAIN}.crt"
    local key_file="${ssl_dir}/${DOMAIN}.key"
    
    # Verifica se i certificati esistono già
    if [[ -f "${cert_file}" && -f "${key_file}" ]]; then
        log "INFO" "Certificati già esistenti, creazione backup..." "${LOG_FILE}"
        backup_file "${cert_file}" "${LOG_FILE}"
        backup_file "${key_file}" "${LOG_FILE}"
    fi
    
    # Genera certificato self-signed
    log "INFO" "Generazione certificato self-signed per ${DOMAIN}..." "${LOG_FILE}"
    
    # Crea file di configurazione OpenSSL
    local openssl_config="/tmp/openssl.cnf"
    cat > "${openssl_config}" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = IT
ST = Italia
L = Firenze
O = 42 Firenze
OU = WordPress Installer
CN = ${DOMAIN}
emailAddress = admin@${DOMAIN}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = www.${DOMAIN}
EOF
    
    # Genera chiave privata e certificato
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${key_file}" -out "${cert_file}" \
        -config "${openssl_config}" || {
        log "ERROR" "Impossibile generare certificato self-signed" "${LOG_FILE}"
        return 1
    }
    
    # Imposta permessi corretti
    chmod 600 "${key_file}"
    chmod 644 "${cert_file}"
    
    # Rimuovi file di configurazione temporaneo
    rm -f "${openssl_config}"
    
    log "SUCCESS" "Certificato self-signed generato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Genera certificato Let's Encrypt
# Ottiene un certificato SSL da Let's Encrypt
generate_letsencrypt_certificate() {
    log "STEP" "Generazione certificato Let's Encrypt" "${LOG_FILE}"
    
    # Verifica se il dominio è valido
    if [[ "${DOMAIN}" == "localhost" ]]; then
        log "ERROR" "Impossibile ottenere certificato Let's Encrypt per localhost" "${LOG_FILE}"
        return 1
    fi
    
    # Verifica se siamo in ambiente WSL
    if detect_wsl "${LOG_FILE}"; then
        log "ERROR" "Let's Encrypt non supportato in ambiente WSL" "${LOG_FILE}"
        return 1
    }
    
    # Verifica connessione internet
    check_internet_connection "${LOG_FILE}" || {
        log "ERROR" "Connessione internet non disponibile" "${LOG_FILE}"
        return 1
    }
    
    # Ottieni certificato Let's Encrypt
    log "INFO" "Richiesta certificato Let's Encrypt per ${DOMAIN}..." "${LOG_FILE}"
    
    # Usa Certbot per ottenere e installare il certificato
    certbot --nginx \
        --non-interactive \
        --agree-tos \
        --email "${ADMIN_EMAIL}" \
        --domains "${DOMAIN},www.${DOMAIN}" \
        --redirect || {
        log "ERROR" "Impossibile ottenere certificato Let's Encrypt" "${LOG_FILE}"
        return 1
    }
    
    log "SUCCESS" "Certificato Let's Encrypt ottenuto correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Configura Nginx per HTTPS
# Aggiorna la configurazione Nginx per supportare HTTPS
configure_nginx_https() {
    log "STEP" "Configurazione Nginx per HTTPS" "${LOG_FILE}"
    
    # Percorso configurazione Nginx
    local nginx_conf="/etc/nginx/sites-available/wordpress"
    
    # Verifica se la configurazione esiste
    if [[ ! -f "${nginx_conf}" ]]; then
        log "ERROR" "Configurazione Nginx non trovata: ${nginx_conf}" "${LOG_FILE}"
        return 1
    }
    
    # Backup configurazione esistente
    backup_file "${nginx_conf}" "${LOG_FILE}"
    
    # Seleziona il template appropriato
    local template
    if [[ "${ENV_MODE}" == "prod" ]]; then
        template="${ROOT_DIR}/templates/nginx-prod.conf"
    else
        template="${ROOT_DIR}/templates/nginx-local.conf"
    }
    
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
        "SSL_TYPE=${SSL_TYPE}"
    )
    
    # Se SSL_TYPE è selfsigned, aggiungi percorsi certificati
    if [[ "${SSL_TYPE}" == "selfsigned" ]]; then
        vars+=(
            "SSL_CERT=/etc/nginx/ssl/${DOMAIN}.crt"
            "SSL_KEY=/etc/nginx/ssl/${DOMAIN}.key"
        )
    fi
    
    # Applica template
    replace_in_template "${template}" "${nginx_conf}" "${LOG_FILE}" "${vars[@]}" || {
        log "ERROR" "Impossibile applicare template Nginx" "${LOG_FILE}"
        return 1
    }
    
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
    
    log "SUCCESS" "Nginx configurato per HTTPS" "${LOG_FILE}"
    return 0
}

# Funzione: Aggiorna WordPress per HTTPS
# Aggiorna la configurazione di WordPress per utilizzare HTTPS
update_wordpress_https() {
    log "STEP" "Aggiornamento WordPress per HTTPS" "${LOG_FILE}"
    
    # Verifica se WordPress è installato
    if ! wp core is-installed --path="${WP_DIR}" --allow-root &>/dev/null; then
        log "ERROR" "WordPress non installato" "${LOG_FILE}"
        return 1
    }
    
    # Aggiorna URL sito
    log "INFO" "Aggiornamento URL sito a HTTPS..." "${LOG_FILE}"
    cd "${WP_DIR}"
    
    # Aggiorna home e siteurl
    wp option update home "https://${DOMAIN}" --allow-root || {
        log "ERROR" "Impossibile aggiornare URL home" "${LOG_FILE}"
        return 1
    }
    
    wp option update siteurl "https://${DOMAIN}" --allow-root || {
        log "ERROR" "Impossibile aggiornare URL sito" "${LOG_FILE}"
        return 1
    }
    
    # Aggiorna wp-config.php per forzare HTTPS
    log "INFO" "Aggiornamento wp-config.php per HTTPS..." "${LOG_FILE}"
    
    # Verifica se la configurazione HTTPS è già presente
    if grep -q "FORCE_SSL_ADMIN" "${WP_DIR}/wp-config.php"; then
        log "INFO" "Configurazione HTTPS già presente in wp-config.php" "${LOG_FILE}"
    else
        # Aggiungi configurazione HTTPS
        sed -i "/\$table_prefix/i define( 'FORCE_SSL_ADMIN', true );" "${WP_DIR}/wp-config.php"
    fi
    
    log "SUCCESS" "WordPress aggiornato per HTTPS" "${LOG_FILE}"
    return 0
}

# ============================================================================== #
# SEZIONE: Funzione principale
# ============================================================================== #

# Funzione: Main
# Funzione principale che gestisce il flusso del programma
main() {
    log "STEP" "Inizio configurazione SSL" "${LOG_FILE}"
    
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
    
    # Verifica se l'installazione di WordPress è stata completata
    if ! check_installation_status "wordpress_setup"; then
        log "ERROR" "Installazione WordPress non completata" "${LOG_FILE}"
        echo -e "\n${RED}L'installazione di WordPress non è stata completata.${NC}"
        echo -e "${RED}Eseguire prima lo script 3_wordpress_setup.sh${NC}"
        exit 1
    fi
    
    # Verifica se la configurazione SSL è già stata completata
    if check_installation_status "ssl_setup"; then
        log "INFO" "Configurazione SSL già completata" "${LOG_FILE}"
        
        # Chiedi all'utente se vuole riconfigurare
        if [[ "${INTERACTIVE:-true}" == "true" ]]; then
            echo -e "\n${YELLOW}La configurazione SSL è già stata completata.${NC}"
            echo -n "Vuoi riconfigurare? [s/N]: "
            read -r response
            
            if [[ ! "${response}" =~ ^[Ss]$ ]]; then
                log "INFO" "Riconfigurazione SSL saltata su richiesta dell'utente" "${LOG_FILE}"
                exit 0
            fi
        else
            # In modalità non interattiva, salta se richiesto
            if [[ "${SKIP_SSL_SETUP:-false}" == "true" ]]; then
                log "INFO" "Configurazione SSL saltata come richiesto" "${LOG_FILE}"
                exit 0
            fi
        fi
    fi
    
    # Verifica se SSL è disabilitato
    if [[ "${SSL_TYPE}" == "none" ]]; then
        log "INFO" "SSL disabilitato nella configurazione" "${LOG_FILE}"
        echo -e "\n${YELLOW}SSL disabilitato nella configurazione.${NC}"
        echo -e "${YELLOW}Per abilitare SSL, modificare SSL_TYPE in config.cfg${NC}"
        
        # Imposta stato installazione comunque
        set_installation_status "ssl_setup"
        exit 0
    fi
    
    # Verifica prerequisiti SSL
    check_ssl_prerequisites || {
        log "ERROR" "Prerequisiti SSL non soddisfatti" "${LOG_FILE}"
        exit 1
    }
    
    # Genera certificato in base al tipo
    if [[ "${SSL_TYPE}" == "selfsigned" ]]; then
        generate_selfsigned_certificate || {
            log "ERROR" "Generazione certificato self-signed fallita" "${LOG_FILE}"
            exit 1
        }
    elif [[ "${SSL_TYPE}" == "letsencrypt" ]]; then
        generate_letsencrypt_certificate || {
            log "ERROR" "Generazione certificato Let's Encrypt fallita" "${LOG_FILE}"
            exit 1
        }
    else
        log "ERROR" "Tipo SSL non valido: ${SSL_TYPE}" "${LOG_FILE}"
        exit 1
    fi
    
    # Configura Nginx per HTTPS
    configure_nginx_https || {
        log "ERROR" "Configurazione Nginx per HTTPS fallita" "${LOG_FILE}"
        exit 1
    }
    
    # Aggiorna WordPress per HTTPS
    update_wordpress_https || {
        log "ERROR" "Aggiornamento WordPress per HTTPS fallito" "${LOG_FILE}"
        exit 1
    }
    
    # Imposta stato installazione
    set_installation_status "ssl_setup"
    
    log "SUCCESS" "Configurazione SSL completata con successo" "${LOG_FILE}"
    
    # Mostra informazioni di riepilogo
    echo -e "\n${BOLD}CONFIGURAZIONE SSL COMPLETATA${NC}"
    echo -e "Dominio: ${DOMAIN}"
    echo -e "Tipo SSL: ${SSL_TYPE}"
    echo -e "URL: https://${DOMAIN}"
    echo -e "Log: ${LOG_FILE}"
    echo ""
    
    exit 0
}

# ============================================================================== #
# SEZIONE: Esecuzione principale
# ============================================================================== #

# Esegui la funzione principale
main
