#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    0_launcher.sh                                      :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Script launcher principale per l'installazione di WordPress
# Questo script è il punto di ingresso dell'installatore e presenta un menu
# interattivo per guidare l'utente attraverso il processo di installazione

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
# Questo garantisce che lo script funzioni correttamente indipendentemente 
# dalla directory da cui viene eseguito
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Percorso della directory principale (root) del progetto
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

# Percorsi delle sottodirectory principali
CONFIG_DIR="${ROOT_DIR}/config"       # Directory configurazione
LOGS_DIR="${ROOT_DIR}/logs"           # Directory log
STATE_DIR="${ROOT_DIR}/state"         # Directory stato

# File di log principale
LOG_FILE="${LOGS_DIR}/installer.log"

# Crea directory log se non esiste
mkdir -p "${LOGS_DIR}"

# ============================================================================== #
# SEZIONE: Caricamento librerie comuni
# ============================================================================== #

# Carica la libreria di funzioni comuni
# Questa libreria contiene funzioni di utilità generale utilizzate da tutti gli script
source "${SCRIPT_DIR}/lib/common.sh"

# ============================================================================== #
# SEZIONE: Configurazione trap per gestione errori
# ============================================================================== #

# Configura trap per gestire gli errori
# Questa funzione viene chiamata automaticamente quando si verifica un errore
trap 'handle_error ${LINENO} "0_launcher.sh" "${LOG_FILE}"' ERR

# ============================================================================== #
# SEZIONE: Funzioni di utilità per il launcher
# ============================================================================== #

# Funzione: Mostra il banner di benvenuto
# Visualizza un banner ASCII art per l'installatore
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   █ █ █ █▀█   █ █▄ █ █▀ ▀█▀ ▄▀█ █   █   █▀▀ █▀█             ║"
    echo "║   ▀▄▀▄▀ █▀▀   █ █ ▀█ ▄█  █  █▀█ █▄▄ █▄▄ ██▄ █▀▄             ║"
    echo "║                                                               ║"
    echo "║   Installatore Automatico WordPress                           ║"
    echo "║   Versione: 1.0.0                                             ║"
    echo "║   Autore: thenizix@protonmail.com                             ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Funzione: Mostra il menu principale
# Visualizza le opzioni disponibili all'utente
show_menu() {
    echo -e "\n${BOLD}MENU PRINCIPALE${NC}"
    echo -e "Seleziona un'opzione:\n"
    echo -e "  ${CYAN}1)${NC} Installazione Completa"
    echo -e "  ${CYAN}2)${NC} Configura Sistema"
    echo -e "  ${CYAN}3)${NC} Configura Database"
    echo -e "  ${CYAN}4)${NC} Installa WordPress"
    echo -e "  ${CYAN}5)${NC} Configura SSL"
    echo -e "  ${CYAN}6)${NC} Verifica Finale"
    echo -e "  ${CYAN}7)${NC} Visualizza Stato Installazione"
    echo -e "  ${CYAN}8)${NC} Modifica Configurazione"
    echo -e "  ${CYAN}9)${NC} Esci"
    echo ""
}

# Funzione: Esegui uno script
# Esegue uno script specifico e gestisce eventuali errori
# Parametri:
#   $1 - Percorso dello script da eseguire
run_script() {
    local script_path="$1"
    
    # Verifica che lo script esista
    if [[ ! -f "${script_path}" ]]; then
        log "ERROR" "Script non trovato: ${script_path}" "${LOG_FILE}"
        echo -e "\n${RED}Script non trovato: ${script_path}${NC}"
        echo -e "${RED}Premere un tasto per continuare...${NC}"
        read -n 1
        return 1
    fi
    
    # Esegui lo script
    log "INFO" "Esecuzione script: ${script_path}" "${LOG_FILE}"
    
    # Imposta permessi di esecuzione
    chmod +x "${script_path}"
    
    # Esegui lo script
    "${script_path}"
    
    # Verifica il codice di uscita
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log "ERROR" "Script terminato con errore (codice: ${exit_code}): ${script_path}" "${LOG_FILE}"
        echo -e "\n${RED}Script terminato con errore (codice: ${exit_code})${NC}"
        echo -e "${RED}Consultare il log per maggiori dettagli: ${LOG_FILE}${NC}"
        echo -e "${RED}Premere un tasto per continuare...${NC}"
        read -n 1
        return ${exit_code}
    fi
    
    log "SUCCESS" "Script eseguito con successo: ${script_path}" "${LOG_FILE}"
    return 0
}

# Funzione: Mostra lo stato dell'installazione
# Visualizza lo stato di completamento di ogni componente
show_installation_status() {
    echo -e "\n${BOLD}STATO INSTALLAZIONE${NC}\n"
    
    # Componenti da verificare
    local components=(
        "system_setup:Configurazione Sistema"
        "mysql_setup:Configurazione Database"
        "wordpress_setup:Installazione WordPress"
        "ssl_setup:Configurazione SSL"
        "final_config:Verifica Finale"
    )
    
    # Verifica ogni componente
    for comp in "${components[@]}"; do
        local comp_id=$(echo "${comp}" | cut -d: -f1)
        local comp_name=$(echo "${comp}" | cut -d: -f2)
        
        if check_installation_status "${comp_id}"; then
            echo -e "  ${GREEN}✓${NC} ${comp_name}"
        else
            echo -e "  ${RED}✗${NC} ${comp_name}"
        fi
    done
    
    echo -e "\nPremere un tasto per continuare..."
    read -n 1
}

# Funzione: Modifica la configurazione
# Apre il file di configurazione in un editor di testo
edit_configuration() {
    # Verifica che il file di configurazione esista
    if [[ ! -f "${CONFIG_DIR}/config.cfg" ]]; then
        log "ERROR" "File di configurazione non trovato: ${CONFIG_DIR}/config.cfg" "${LOG_FILE}"
        echo -e "\n${RED}File di configurazione non trovato: ${CONFIG_DIR}/config.cfg${NC}"
        echo -e "${RED}Premere un tasto per continuare...${NC}"
        read -n 1
        return 1
    fi
    
    # Determina l'editor da utilizzare
    local editor="nano"
    if [[ -n "${EDITOR:-}" ]]; then
        editor="${EDITOR}"
    elif command -v vim &> /dev/null; then
        editor="vim"
    elif command -v nano &> /dev/null; then
        editor="nano"
    else
        log "WARNING" "Editor di testo non trovato, utilizzo di cat per visualizzare il file" "${LOG_FILE}"
        echo -e "\n${YELLOW}Editor di testo non trovato, visualizzazione del file:${NC}\n"
        cat "${CONFIG_DIR}/config.cfg"
        echo -e "\n${YELLOW}Impossibile modificare il file. Premere un tasto per continuare...${NC}"
        read -n 1
        return 1
    fi
    
    # Crea un backup del file di configurazione
    backup_file "${CONFIG_DIR}/config.cfg" "${LOG_FILE}"
    
    # Apri il file nell'editor
    log "INFO" "Apertura file di configurazione nell'editor: ${editor}" "${LOG_FILE}"
    echo -e "\n${CYAN}Apertura file di configurazione nell'editor: ${editor}${NC}"
    echo -e "${CYAN}Salvare e uscire dall'editor per continuare...${NC}\n"
    
    # Attendi un secondo per permettere all'utente di leggere il messaggio
    sleep 1
    
    # Apri l'editor
    ${editor} "${CONFIG_DIR}/config.cfg"
    
    echo -e "\n${GREEN}File di configurazione aggiornato.${NC}"
    echo -e "${GREEN}Premere un tasto per continuare...${NC}"
    read -n 1
    return 0
}

# Funzione: Esegui installazione completa
# Esegue tutti gli script di installazione in sequenza
run_full_installation() {
    log "STEP" "Avvio installazione completa" "${LOG_FILE}"
    
    # Script da eseguire in sequenza
    local scripts=(
        "${SCRIPT_DIR}/1_system_setup.sh"
        "${SCRIPT_DIR}/2_mysql_setup.sh"
        "${SCRIPT_DIR}/3_wordpress_setup.sh"
        "${SCRIPT_DIR}/4_ssl_setup.sh"
        "${SCRIPT_DIR}/5_final_config.sh"
    )
    
    # Esegui ogni script
    for script in "${scripts[@]}"; do
        run_script "${script}" || {
            log "ERROR" "Installazione completa fallita durante l'esecuzione di: ${script}" "${LOG_FILE}"
            echo -e "\n${RED}Installazione completa fallita.${NC}"
            echo -e "${RED}Consultare il log per maggiori dettagli: ${LOG_FILE}${NC}"
            echo -e "${RED}Premere un tasto per continuare...${NC}"
            read -n 1
            return 1
        }
    done
    
    log "SUCCESS" "Installazione completa eseguita con successo" "${LOG_FILE}"
    echo -e "\n${GREEN}Installazione completa eseguita con successo!${NC}"
    echo -e "${GREEN}Premere un tasto per continuare...${NC}"
    read -n 1
    return 0
}

# ============================================================================== #
# SEZIONE: Funzione principale
# ============================================================================== #

# Funzione: Main
# Funzione principale che gestisce il flusso del programma
main() {
    # Inizializza l'ambiente
    init_environment
    
    # Verifica prerequisiti
    check_prerequisites "${LOG_FILE}" || {
        log "ERROR" "Prerequisiti non soddisfatti" "${LOG_FILE}"
        echo -e "\n${RED}Prerequisiti non soddisfatti. Impossibile continuare.${NC}"
        echo -e "${RED}Consultare il log per maggiori dettagli: ${LOG_FILE}${NC}"
        exit 1
    }
    
    # Carica configurazione
    if [[ -f "${CONFIG_DIR}/config.cfg" ]]; then
        source "${CONFIG_DIR}/config.cfg"
    else
        log "ERROR" "File di configurazione non trovato: ${CONFIG_DIR}/config.cfg" "${LOG_FILE}"
        echo -e "\n${RED}File di configurazione non trovato: ${CONFIG_DIR}/config.cfg${NC}"
        echo -e "${RED}Assicurarsi che il file esista e sia leggibile.${NC}"
        exit 1
    }
    
    # Verifica se la modalità interattiva è disabilitata
    if [[ "${INTERACTIVE:-true}" == "false" ]]; then
        log "INFO" "Modalità non interattiva attivata, avvio installazione completa" "${LOG_FILE}"
        run_full_installation
        exit $?
    fi
    
    # Loop principale del menu
    while true; do
        # Mostra banner e menu
        show_banner
        show_menu
        
        # Richiedi input utente
        echo -n "Seleziona un'opzione [1-9]: "
        read -r choice
        
        # Gestisci la scelta dell'utente
        case "${choice}" in
            1)
                # Installazione completa
                run_full_installation
                ;;
                
            2)
                # Configura sistema
                run_script "${SCRIPT_DIR}/1_system_setup.sh"
                ;;
                
            3)
                # Configura database
                run_script "${SCRIPT_DIR}/2_mysql_setup.sh"
                ;;
                
            4)
                # Installa WordPress
                run_script "${SCRIPT_DIR}/3_wordpress_setup.sh"
                ;;
                
            5)
                # Configura SSL
                run_script "${SCRIPT_DIR}/4_ssl_setup.sh"
                ;;
                
            6)
                # Verifica finale
                run_script "${SCRIPT_DIR}/5_final_config.sh"
                ;;
                
            7)
                # Visualizza stato installazione
                show_installation_status
                ;;
                
            8)
                # Modifica configurazione
                edit_configuration
                ;;
                
            9)
                # Esci
                log "INFO" "Uscita dal programma" "${LOG_FILE}"
                echo -e "\n${GREEN}Grazie per aver utilizzato l'installatore WordPress!${NC}"
                exit 0
                ;;
                
            *)
                # Opzione non valida
                echo -e "\n${RED}Opzione non valida. Premere un tasto per continuare...${NC}"
                read -n 1
                ;;
        esac
    done
}

# ============================================================================== #
# SEZIONE: Esecuzione principale
# ============================================================================== #

# Esegui la funzione principale
main
