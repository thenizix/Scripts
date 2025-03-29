#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    5_final_config.sh                                  :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Script di configurazione finale e verifica
# Questo script si occupa di:
# - Verificare che tutti i componenti siano installati correttamente
# - Eseguire ottimizzazioni finali
# - Configurare backup automatici (opzionale)
# - Mostrare un riepilogo dell'installazione

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
LOG_FILE="${LOGS_DIR}/final_config.log"
mkdir -p "${LOGS_DIR}"
chmod 750 "${LOGS_DIR}"

# ============================================================================== #
# SEZIONE: Configurazione trap per gestione errori
# ============================================================================== #

# Configura trap per gestire gli errori
# Questa funzione viene chiamata automaticamente quando si verifica un errore
trap 'handle_error ${LINENO} "5_final_config.sh" "${LOG_FILE}"' ERR

# ============================================================================== #
# SEZIONE: Funzioni di verifica e ottimizzazione
# ============================================================================== #

# Funzione: Verifica componenti installati
# Controlla che tutti i componenti necessari siano installati correttamente
verify_components() {
    log "STEP" "Verifica componenti installati" "${LOG_FILE}"
    
    # Componenti da verificare
    local components=(
        "system_setup:Configurazione Sistema"
        "mysql_setup:Configurazione Database"
        "wordpress_setup:Installazione WordPress"
    )
    
    # Aggiungi SSL se non è disabilitato
    if [[ "${SSL_TYPE}" != "none" ]]; then
        components+=("ssl_setup:Configurazione SSL")
    fi
    
    # Verifica ogni componente
    local all_ok=true
    for comp in "${components[@]}"; do
        local comp_id=$(echo "${comp}" | cut -d: -f1)
        local comp_name=$(echo "${comp}" | cut -d: -f2)
        
        log "INFO" "Verifica ${comp_name}..." "${LOG_FILE}"
        
        if check_installation_status "${comp_id}"; then
            log "SUCCESS" "${comp_name} completato" "${LOG_FILE}"
        else
            log "ERROR" "${comp_name} non completato" "${LOG_FILE}"
            all_ok=false
        fi
    done
    
    # Verifica se tutti i componenti sono installati
    if [[ "${all_ok}" == "true" ]]; then
        log "SUCCESS" "Tutti i componenti sono installati correttamente" "${LOG_FILE}"
        return 0
    else
        log "ERROR" "Alcuni componenti non sono installati correttamente" "${LOG_FILE}"
        return 1
    fi
}

# Funzione: Verifica servizi attivi
# Controlla che tutti i servizi necessari siano in esecuzione
verify_services() {
    log "STEP" "Verifica servizi attivi" "${LOG_FILE}"
    
    # Servizi da verificare
    local services=(
        "nginx:Nginx"
        "mysql:MySQL/MariaDB"
        "php${PHP_VERSION}-fpm:PHP-FPM"
    )
    
    # Verifica ogni servizio
    local all_ok=true
    for svc in "${services[@]}"; do
        local svc_id=$(echo "${svc}" | cut -d: -f1)
        local svc_name=$(echo "${svc}" | cut -d: -f2)
        
        log "INFO" "Verifica servizio ${svc_name}..." "${LOG_FILE}"
        
        if check_service_status "${svc_id}" "${LOG_FILE}"; then
            log "SUCCESS" "Servizio ${svc_name} attivo" "${LOG_FILE}"
        else
            log "ERROR" "Servizio ${svc_name} non attivo" "${LOG_FILE}"
            all_ok=false
            
            # Prova ad avviare il servizio
            log "INFO" "Tentativo di avvio servizio ${svc_name}..." "${LOG_FILE}"
            if start_service "${svc_id}" "${LOG_FILE}"; then
                log "SUCCESS" "Servizio ${svc_name} avviato correttamente" "${LOG_FILE}"
                all_ok=true
            else
                log "ERROR" "Impossibile avviare servizio ${svc_name}" "${LOG_FILE}"
            fi
        fi
    done
    
    # Verifica se tutti i servizi sono attivi
    if [[ "${all_ok}" == "true" ]]; then
        log "SUCCESS" "Tutti i servizi sono attivi" "${LOG_FILE}"
        return 0
    else
        log "ERROR" "Alcuni servizi non sono attivi" "${LOG_FILE}"
        return 1
    fi
}

# Funzione: Verifica accesso WordPress
# Controlla che WordPress sia accessibile via web
verify_wordpress_access() {
    log "STEP" "Verifica accesso WordPress" "${LOG_FILE}"
    
    # Determina URL WordPress
    local wp_url
    if [[ "${SSL_TYPE}" != "none" && check_installation_status "ssl_setup" ]]; then
        wp_url="https://${DOMAIN}"
    else
        wp_url="http://${DOMAIN}:${SERVER_PORT}"
    fi
    
    # Verifica accesso WordPress
    log "INFO" "Verifica accesso a ${wp_url}..." "${LOG_FILE}"
    
    # Usa curl per verificare l'accesso
    if curl -s -o /dev/null -w "%{http_code}" "${wp_url}" | grep -q "200"; then
        log "SUCCESS" "WordPress accessibile via web" "${LOG_FILE}"
        return 0
    else
        log "ERROR" "WordPress non accessibile via web" "${LOG_FILE}"
        return 1
    fi
}

# Funzione: Ottimizza WordPress
# Esegue ottimizzazioni finali per WordPress
optimize_wordpress() {
    log "STEP" "Ottimizzazione WordPress" "${LOG_FILE}"
    
    # Verifica se WordPress è installato
    if ! wp core is-installed --path="${WP_DIR}" --allow-root &>/dev/null; then
        log "ERROR" "WordPress non installato" "${LOG_FILE}"
        return 1
    fi
    
    # Ottimizzazioni da eseguire
    log "INFO" "Esecuzione ottimizzazioni WordPress..." "${LOG_FILE}"
    cd "${WP_DIR}"
    
    # Aggiorna permalink
    log "INFO" "Configurazione permalink..." "${LOG_FILE}"
    wp rewrite structure '/%postname%/' --allow-root || {
        log "WARNING" "Impossibile configurare permalink" "${LOG_FILE}"
    }
    
    # Rimuovi plugin non necessari
    log "INFO" "Rimozione plugin non necessari..." "${LOG_FILE}"
    wp plugin delete hello akismet --allow-root || {
        log "WARNING" "Impossibile rimuovere plugin non necessari" "${LOG_FILE}"
    }
    
    # Configura aggiornamenti automatici
    if [[ "${AUTO_UPDATE}" == "true" ]]; then
        log "INFO" "Configurazione aggiornamenti automatici..." "${LOG_FILE}"
        
        # Aggiungi configurazione a wp-config.php
        if ! grep -q "WP_AUTO_UPDATE_CORE" "${WP_DIR}/wp-config.php"; then
            sed -i "/\$table_prefix/i define( 'WP_AUTO_UPDATE_CORE', true );" "${WP_DIR}/wp-config.php"
        fi
        
        # Configura cron per aggiornamenti
        if ! crontab -l | grep -q "wp-cron.php"; then
            (crontab -l 2>/dev/null; echo "0 3 * * * curl -s ${wp_url}/wp-cron.php > /dev/null 2>&1") | crontab -
        fi
    fi
    
    log "SUCCESS" "WordPress ottimizzato correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Configura backup automatici
# Configura backup automatici per WordPress e database
configure_backups() {
    log "STEP" "Configurazione backup automatici" "${LOG_FILE}"
    
    # Chiedi all'utente se vuole configurare backup automatici
    if [[ "${INTERACTIVE:-true}" == "true" ]]; then
        echo -e "\n${CYAN}Vuoi configurare backup automatici?${NC}"
        echo -n "Questa operazione configurerà un cron job per backup giornalieri [s/N]: "
        read -r response
        
        if [[ ! "${response}" =~ ^[Ss]$ ]]; then
            log "INFO" "Configurazione backup saltata su richiesta dell'utente" "${LOG_FILE}"
            return 0
        fi
    else
        # In modalità non interattiva, salta
        log "INFO" "Configurazione backup saltata in modalità non interattiva" "${LOG_FILE}"
        return 0
    fi
    
    # Directory backup
    local backup_dir="/var/backups/wordpress"
    
    # Crea directory backup
    log "INFO" "Creazione directory backup ${backup_dir}..." "${LOG_FILE}"
    mkdir -p "${backup_dir}"
    chmod 750 "${backup_dir}"
    
    # Crea script di backup
    local backup_script="/usr/local/bin/wp_backup.sh"
    log "INFO" "Creazione script backup ${backup_script}..." "${LOG_FILE}"
    
    cat > "${backup_script}" <<EOF
#!/bin/bash
# Script di backup automatico per WordPress
# Generato da wpinstaller

# Directory di backup
BACKUP_DIR="${backup_dir}"

# Data corrente
DATE=\$(date +%Y%m%d)

# Directory WordPress
WP_DIR="${WP_DIR}"

# Credenziali database
source "${MYSQL_CREDS_FILE}"

# Crea backup database
mysqldump -u "\${MYSQL_WP_USER}" -p"\${MYSQL_WP_PASS}" "\${MYSQL_WP_DB}" > "\${BACKUP_DIR}/db_\${DATE}.sql"

# Crea backup file WordPress
tar -czf "\${BACKUP_DIR}/wp_\${DATE}.tar.gz" -C "\$(dirname "\${WP_DIR}")" "\$(basename "\${WP_DIR}")"

# Rimuovi backup più vecchi di 7 giorni
find "\${BACKUP_DIR}" -name "*.sql" -mtime +7 -delete
find "\${BACKUP_DIR}" -name "*.tar.gz" -mtime +7 -delete

# Log
echo "Backup completato: \$(date)" >> "\${BACKUP_DIR}/backup.log"
EOF
    
    # Imposta permessi script
    chmod 700 "${backup_script}"
    
    # Configura cron job
    log "INFO" "Configurazione cron job per backup giornalieri..." "${LOG_FILE}"
    (crontab -l 2>/dev/null; echo "0 2 * * * ${backup_script} > /dev/null 2>&1") | crontab -
    
    log "SUCCESS" "Backup automatici configurati correttamente" "${LOG_FILE}"
    return 0
}

# Funzione: Mostra riepilogo installazione
# Visualizza un riepilogo di tutte le informazioni dell'installazione
show_installation_summary() {
    log "STEP" "Riepilogo installazione" "${LOG_FILE}"
    
    # Carica credenziali
    if [[ -f "${MYSQL_CREDS_FILE}" ]]; then
        load_credentials "${MYSQL_CREDS_FILE}" "${LOG_FILE}"
    fi
    
    if [[ -f "${WP_CREDS_FILE}" ]]; then
        load_credentials "${WP_CREDS_FILE}" "${LOG_FILE}"
    fi
    
    # Determina URL WordPress
    local wp_url
    if [[ "${SSL_TYPE}" != "none" && check_installation_status "ssl_setup" ]]; then
        wp_url="https://${DOMAIN}"
    else
        wp_url="http://${DOMAIN}:${SERVER_PORT}"
    fi
    
    # Mostra riepilogo
    echo -e "\n${BOLD}${CYAN}=============================================${NC}"
    echo -e "${BOLD}${CYAN}     RIEPILOGO INSTALLAZIONE WORDPRESS     ${NC}"
    echo -e "${BOLD}${CYAN}=============================================${NC}\n"
    
    echo -e "${BOLD}Informazioni generali:${NC}"
    echo -e "  Sistema: ${DISTRO_NAME} ${DISTRO_VERSION}"
    echo -e "  WSL: $(detect_wsl "${LOG_FILE}" && echo "Sì" || echo "No")"
    echo -e "  Directory WordPress: ${WP_DIR}"
    echo -e "  URL: ${wp_url}"
    
    echo -e "\n${BOLD}Credenziali database:${NC}"
    echo -e "  Database: ${MYSQL_WP_DB:-N/A}"
    echo -e "  Utente: ${MYSQL_WP_USER:-N/A}"
    echo -e "  Password: ${MYSQL_WP_PASS:-N/A}"
    
    echo -e "\n${BOLD}Credenziali WordPress:${NC}"
    echo -e "  Utente: ${WP_ADMIN_USER:-N/A}"
    echo -e "  Password: ${WP_ADMIN_PASS:-N/A}"
    echo -e "  Email: ${WP_ADMIN_EMAIL:-N/A}"
    
    echo -e "\n${BOLD}Configurazione:${NC}"
    echo -e "  SSL: ${SSL_TYPE}"
    echo -e "  Debug: ${WP_DEBUG}"
    echo -e "  Aggiornamenti automatici: ${AUTO_UPDATE}"
    
    echo -e "\n${BOLD}File importanti:${NC}"
    echo -e "  Configurazione: ${CONFIG_DIR}/config.cfg"
    echo -e "  Credenziali MySQL: ${MYSQL_CREDS_FILE}"
    echo -e "  Credenziali WordPress: ${WP_CREDS_FILE}"
    echo -e "  Log: ${LOGS_DIR}"
    
    echo -e "\n${BOLD}${GREEN}Installazione completata con successo!${NC}"
    echo -e "${BOLD}${GREEN}Accedi al pannello di amministrazione: ${wp_url}/wp-admin${NC}\n"
    
    # Salva riepilogo in un file
    local summary_file="${ROOT_DIR}/installation_summary.txt"
    log "INFO" "Salvataggio riepilogo in ${summary_file}..." "${LOG_FILE}"
    
    cat > "${summary_file}" <<EOF
============================================
     RIEPILOGO INSTALLAZIONE WORDPRESS     
============================================

Informazioni generali:
  Sistema: ${DISTRO_NAME} ${DISTRO_VERSION}
  WSL: $(detect_wsl "${LOG_FILE}" && echo "Sì" || echo "No")
  Directory WordPress: ${WP_DIR}
  URL: ${wp_url}

Credenziali database:
  Database: ${MYSQL_WP_DB:-N/A}
  Utente: ${MYSQL_WP_USER:-N/A}
  Password: ${MYSQL_WP_PASS:-N/A}

Credenziali WordPress:
  Utente: ${WP_ADMIN_USER:-N/A}
  Password: ${WP_ADMIN_PASS:-N/A}
  Email: ${WP_ADMIN_EMAIL:-N/A}

Configurazione:
  SSL: ${SSL_TYPE}
  Debug: ${WP_DEBUG}
  Aggiornamenti automatici: ${AUTO_UPDATE}

File importanti:
  Configurazione: ${CONFIG_DIR}/config.cfg
  Credenziali MySQL: ${MYSQL_CREDS_FILE}
  Credenziali WordPress: ${WP_CREDS_FILE}
  Log: ${LOGS_DIR}

Installazione completata con successo!
Accedi al pannello di amministrazione: ${wp_url}/wp-admin

Data installazione: $(date "+%Y-%m-%d %H:%M:%S")
EOF
    
    # Imposta permessi file riepilogo
    chmod 600 "${summary_file}"
    
    log "SUCCESS" "Riepilogo installazione completato" "${LOG_FILE}"
    return 0
}

# ============================================================================== #
# SEZIONE: Funzione principale
# ============================================================================== #

# Funzione: Main
# Funzione principale che gestisce il flusso del programma
main() {
    log "STEP" "Inizio configurazione finale" "${LOG_FILE}"
    
    # Inizializza ambiente
    init_environment
    
    # Carica configurazione
    if [[ -f "${CONFIG_DIR}/config.cfg" ]]; then
        source "${CONFIG_DIR}/config.cfg"
    else
        log "ERROR" "File di configurazione non trovato" "${LOG_FILE}"
        exit 1
    }
    
    # Verifica se la configurazione finale è già stata completata
    if check_installation_status "final_config"; then
        log "INFO" "Configurazione finale già completata" "${LOG_FILE}"
        
        # Chiedi all'utente se vuole riconfigurare
        if [[ "${INTERACTIVE:-true}" == "true" ]]; then
            echo -e "\n${YELLOW}La configurazione finale è già stata completata.${NC}"
            echo -n "Vuoi riconfigurare? [s/N]: "
            read -r response
            
            if [[ ! "${response}" =~ ^[Ss]$ ]]; then
                log "INFO" "Riconfigurazione finale saltata su richiesta dell'utente" "${LOG_FILE}"
                exit 0
            fi
        fi
    fi
    
    # Verifica componenti installati
    verify_components || {
        log "ERROR" "Verifica componenti fallita" "${LOG_FILE}"
        echo -e "\n${RED}Alcuni componenti non sono installati correttamente.${NC}"
        echo -e "${RED}Consultare il log per maggiori dettagli: ${LOG_FILE}${NC}"
        exit 1
    }
    
    # Verifica servizi attivi
    verify_services || {
        log "ERROR" "Verifica servizi fallita" "${LOG_FILE}"
        echo -e "\n${RED}Alcuni servizi non sono attivi.${NC}"
        echo -e "${RED}Consultare il log per maggiori dettagli: ${LOG_FILE}${NC}"
        exit 1
    }
    
    # Verifica accesso WordPress
    verify_wordpress_access || {
        log "WARNING" "Verifica accesso WordPress fallita" "${LOG_FILE}"
        echo -e "\n${YELLOW}WordPress non sembra essere accessibile via web.${NC}"
        echo -e "${YELLOW}Verificare la configurazione di rete e del server web.${NC}"
        # Continua comunque, non è critico
    }
    
    # Ottimizza WordPress
    optimize_wordpress || {
        log "WARNING" "Ottimizzazione WordPress fallita" "${LOG_FILE}"
        echo -e "\n${YELLOW}Alcune ottimizzazioni WordPress non sono state applicate.${NC}"
        echo -e "${YELLOW}Consultare il log per maggiori dettagli: ${LOG_FILE}${NC}"
        # Continua comunque, non è critico
    }
    
    # Configura backup automatici
    configure_backups || {
        log "WARNING" "Configurazione backup fallita" "${LOG_FILE}"
        echo -e "\n${YELLOW}Configurazione backup automatici fallita.${NC}"
        echo -e "${YELLOW}Consultare il log per maggiori dettagli: ${LOG_FILE}${NC}"
        # Continua comunque, non è critico
    }
    
    # Mostra riepilogo installazione
    show_installation_summary || {
        log "WARNING" "Visualizzazione riepilogo fallita" "${LOG_FILE}"
        echo -e "\n${YELLOW}Impossibile visualizzare il riepilogo dell'installazione.${NC}"
        echo -e "${YELLOW}Consultare il log per maggiori dettagli: ${LOG_FILE}${NC}"
        # Continua comunque, non è critico
    }
    
    # Imposta stato installazione
    set_installation_status "final_config"
    
    log "SUCCESS" "Configurazione finale completata con successo" "${LOG_FILE}"
    
    exit 0
}

# ============================================================================== #
# SEZIONE: Esecuzione principale
# ============================================================================== #

# Esegui la funzione principale
main
