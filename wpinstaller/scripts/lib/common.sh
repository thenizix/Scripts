#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    common.sh                                          :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Libreria di funzioni comuni per tutti gli script di installazione WordPress
# Questo file contiene funzioni di utilità generale utilizzate da tutti gli script
# dell'installatore, come logging, gestione errori, verifica prerequisiti, ecc.

# ============================================================================== #
# SEZIONE: Impostazioni di sicurezza per bash
# ============================================================================== #
# Queste impostazioni rendono lo script più robusto e sicuro

# set -e: Termina lo script se un comando restituisce un codice di errore
# set -u: Termina lo script se viene utilizzata una variabile non definita
# set -o pipefail: Considera fallito un pipeline se uno qualsiasi dei comandi fallisce
set -euo pipefail

# ============================================================================== #
# SEZIONE: Definizione colori per output
# ============================================================================== #
# Questi codici ANSI permettono di colorare l'output del terminale
# per una migliore leggibilità e distinzione dei messaggi

# Colori di base
readonly RED='\033[0;31m'        # Rosso - per errori e avvisi critici
readonly GREEN='\033[0;32m'      # Verde - per successi e completamenti
readonly YELLOW='\033[0;33m'     # Giallo - per avvisi e attenzioni
readonly BLUE='\033[0;34m'       # Blu - per informazioni generali
readonly MAGENTA='\033[0;35m'    # Magenta - per informazioni di debug
readonly CYAN='\033[0;36m'       # Ciano - per titoli di sezione
readonly BOLD='\033[1m'          # Grassetto - per enfatizzare testo
readonly NC='\033[0m'            # No Color - per terminare la colorazione

# ============================================================================== #
# SEZIONE: Definizione percorsi principali
# ============================================================================== #
# Questi percorsi sono utilizzati in tutto il sistema di installazione
# La definizione centralizzata garantisce coerenza e facilità di manutenzione

# Percorso dello script corrente
readonly SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Percorso della directory principale (root) del progetto
readonly ROOT_DIR=$(cd "${SCRIPT_PATH}/../.." && pwd)

# Percorsi delle sottodirectory principali
readonly CONFIG_DIR="${ROOT_DIR}/config"       # Directory configurazione
readonly SCRIPTS_DIR="${ROOT_DIR}/scripts"     # Directory script
readonly TEMPLATES_DIR="${ROOT_DIR}/templates" # Directory template
readonly LOGS_DIR="${ROOT_DIR}/logs"           # Directory log
readonly STATE_DIR="${ROOT_DIR}/state"         # Directory stato

# ============================================================================== #
# SEZIONE: File di configurazione
# ============================================================================== #
# Percorsi dei file di configurazione principali

# File di configurazione principale
readonly MAIN_CONFIG="${CONFIG_DIR}/config.cfg"

# File di configurazione dell'ambiente (generato durante l'installazione)
readonly ENV_CONFIG="${CONFIG_DIR}/env.cfg"

# ============================================================================== #
# SEZIONE: Funzioni di inizializzazione
# ============================================================================== #

# Funzione: Inizializzazione ambiente
# Questa funzione prepara l'ambiente per l'esecuzione degli script
# creando le directory necessarie, impostando i permessi e caricando
# le configurazioni e le librerie comuni
init_environment() {
    # Crea directory se non esistono
    # Queste directory sono essenziali per il funzionamento dell'installatore
    mkdir -p "${LOGS_DIR}" "${STATE_DIR}"
    
    # Imposta permessi corretti per sicurezza
    # 750 = rwxr-x--- (proprietario: rwx, gruppo: r-x, altri: ---)
    chmod 750 "${LOGS_DIR}" "${STATE_DIR}"
    
    # Carica configurazione principale se esiste
    # Questo file contiene tutte le impostazioni configurabili dell'installatore
    if [[ -f "${MAIN_CONFIG}" ]]; then
        source "${MAIN_CONFIG}"
    fi
    
    # Carica configurazione dell'ambiente se esiste
    # Questo file viene generato durante l'installazione e contiene
    # informazioni specifiche sull'ambiente rilevato
    if [[ -f "${ENV_CONFIG}" ]]; then
        source "${ENV_CONFIG}"
    fi
    
    # Carica altre librerie comuni
    # Queste librerie contengono funzioni specializzate per diversi aspetti
    # dell'installazione
    source "${SCRIPT_PATH}/environment.sh"  # Rilevamento ambiente
    source "${SCRIPT_PATH}/security.sh"     # Gestione sicurezza
    source "${SCRIPT_PATH}/services.sh"     # Gestione servizi
}

# ============================================================================== #
# SEZIONE: Funzioni di logging
# ============================================================================== #

# Funzione: Logging
# Questa funzione gestisce tutti i messaggi di log del sistema
# Parametri:
#   $1 - Livello del log (INFO, SUCCESS, WARNING, ERROR, STEP)
#   $2 - Messaggio da loggare
#   $3 - File di log (opzionale)
log() {
    local level="$1"
    local message="$2"
    local log_file="$3"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Formatta il messaggio in base al livello di log
    # Questo rende l'output più leggibile e facilmente distinguibile
    case "${level}" in
        "INFO")
            # Informazioni generali - colore blu
            echo -e "${BLUE}[INFO]${NC} ${message}"
            ;;
        "SUCCESS")
            # Operazioni completate con successo - colore verde con simbolo di spunta
            echo -e "${GREEN}[✓]${NC} ${message}"
            ;;
        "WARNING")
            # Avvisi non critici - colore giallo con simbolo di attenzione
            echo -e "${YELLOW}[⚠]${NC} ${message}"
            ;;
        "ERROR")
            # Errori critici - colore rosso con simbolo X
            echo -e "${RED}[✗]${NC} ${message}"
            ;;
        "STEP")
            # Titoli di sezione - colore ciano in grassetto
            echo -e "\n${CYAN}[STEP]${NC} ${BOLD}${message}${NC}"
            ;;
        *)
            # Messaggi generici senza formattazione speciale
            echo -e "${message}"
            ;;
    esac
    
    # Scrivi nel log file se specificato
    # Questo permette di mantenere una traccia persistente di tutte le operazioni
    if [[ -n "${log_file}" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${log_file}"
    fi
}

# ============================================================================== #
# SEZIONE: Funzioni di verifica prerequisiti
# ============================================================================== #

# Funzione: Verifica prerequisiti
# Controlla che tutti i prerequisiti necessari per l'installazione siano soddisfatti
# Parametri:
#   $1 - File di log
check_prerequisites() {
    log "STEP" "Verifica prerequisiti di sistema" "$1"
    
    # Verifica se l'utente è root
    # Molte operazioni di installazione richiedono privilegi di root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Questo script deve essere eseguito come root o con sudo" "$1"
        return 1
    fi
    
    # Verifica comandi essenziali
    # Questi comandi sono necessari per il funzionamento dell'installatore
    local essential_commands=("apt-get" "grep" "sed" "awk")
    for cmd in "${essential_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            log "ERROR" "Comando '${cmd}' non trovato. Installare le dipendenze di base." "$1"
            return 1
        fi
    done
    
    log "SUCCESS" "Tutti i prerequisiti sono soddisfatti" "$1"
    return 0
}

# ============================================================================== #
# SEZIONE: Funzioni di gestione errori
# ============================================================================== #

# Funzione: Gestione errori
# Questa funzione viene chiamata automaticamente quando si verifica un errore
# grazie alla trap impostata negli script principali
# Parametri:
#   $1 - Numero di linea dove si è verificato l'errore
#   $2 - Nome dello script
#   $3 - File di log
handle_error() {
    local exit_code=$?
    local line_number=$1
    local script_name=$2
    local log_file=$3
    
    # Logga l'errore nel file di log
    log "ERROR" "Errore nello script ${script_name} alla linea ${line_number} (codice: ${exit_code})" "${log_file}"
    log "ERROR" "Consultare il log per maggiori dettagli: ${log_file}" "${log_file}"
    
    # Notifica l'errore all'utente in modo visibile
    echo -e "\n${RED}=============================================${NC}"
    echo -e "${RED}Si è verificato un errore durante l'esecuzione.${NC}"
    echo -e "${RED}Script: ${script_name}${NC}"
    echo -e "${RED}Linea: ${line_number}${NC}"
    echo -e "${RED}Codice di errore: ${exit_code}${NC}"
    echo -e "${RED}Log: ${log_file}${NC}"
    echo -e "${RED}=============================================${NC}"
    
    # Termina lo script con il codice di errore originale
    exit "${exit_code}"
}

# ============================================================================== #
# SEZIONE: Funzioni di gestione stato installazione
# ============================================================================== #

# Funzione: Verifica stato installazione
# Controlla se un componente è già stato installato correttamente
# Parametri:
#   $1 - Nome del componente
check_installation_status() {
    local component="$1"
    local status_file="${STATE_DIR}/${component}.done"
    
    # Se il file di stato esiste, il componente è stato installato
    if [[ -f "${status_file}" ]]; then
        return 0  # Successo (true)
    else
        return 1  # Fallimento (false)
    fi
}

# Funzione: Imposta stato installazione
# Marca un componente come installato correttamente
# Parametri:
#   $1 - Nome del componente
set_installation_status() {
    local component="$1"
    local status_file="${STATE_DIR}/${component}.done"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Crea il file di stato con timestamp
    echo "${timestamp}" > "${status_file}"
    
    # Imposta permessi restrittivi per sicurezza
    # 600 = rw------- (solo il proprietario può leggere/scrivere)
    chmod 600 "${status_file}"
}

# ============================================================================== #
# SEZIONE: Funzioni di gestione template
# ============================================================================== #

# Funzione: Sostituisci variabili in template
# Sostituisce i placeholder in un file template con valori reali
# Parametri:
#   $1 - File template sorgente
#   $2 - File output destinazione
#   $3 - File di log
#   $@ - Array di variabili nel formato "NOME=valore"
replace_in_template() {
    local template_file="$1"
    local output_file="$2"
    local log_file="$3"
    shift 3
    local vars=("$@")
    
    # Verifica esistenza del template
    if [[ ! -f "${template_file}" ]]; then
        log "ERROR" "Template non trovato: ${template_file}" "${log_file}"
        return 1
    fi
    
    # Copia il template nel file di output
    cp "${template_file}" "${output_file}"
    
    # Sostituisci le variabili
    for var in "${vars[@]}"; do
        # Estrai nome e valore della variabile
        local name=$(echo "${var}" | cut -d= -f1)
        local value=$(echo "${var}" | cut -d= -f2-)
        
        # Escape caratteri speciali in value per evitare problemi con sed
        value=$(echo "${value}" | sed 's/[\/&]/\\&/g')
        
        # Sostituisci nel file
        # Il formato {{NOME}} viene sostituito con il valore
        sed -i "s|{{${name}}}|${value}|g" "${output_file}"
    done
    
    log "SUCCESS" "Template elaborato: ${template_file} -> ${output_file}" "${log_file}"
    return 0
}

# ============================================================================== #
# SEZIONE: Funzioni di utilità
# ============================================================================== #

# Funzione: Verifica connessione internet
# Controlla se è disponibile una connessione internet
# Parametri:
#   $1 - File di log
check_internet_connection() {
    local log_file="$1"
    
    log "INFO" "Verifica connessione internet..." "${log_file}"
    
    # Prova a raggiungere Google DNS (8.8.8.8)
    # Questo è un metodo affidabile per verificare la connettività internet
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log "SUCCESS" "Connessione internet disponibile" "${log_file}"
        return 0
    else
        log "ERROR" "Connessione internet non disponibile" "${log_file}"
        return 1
    fi
}

# Funzione: Backup file
# Crea una copia di backup di un file prima di modificarlo
# Parametri:
#   $1 - Percorso del file da backuppare
#   $2 - File di log
backup_file() {
    local file_path="$1"
    local log_file="$2"
    
    # Verifica esistenza del file
    if [[ ! -f "${file_path}" ]]; then
        log "WARNING" "Impossibile eseguire il backup: file non trovato ${file_path}" "${log_file}"
        return 1
    fi
    
    # Crea nome file di backup con timestamp
    local backup_path="${file_path}.bak.$(date +%Y%m%d%H%M%S)"
    
    # Copia il file
    cp "${file_path}" "${backup_path}"
    
    log "INFO" "Backup creato: ${backup_path}" "${log_file}"
    return 0
}

# Funzione: Richiedi input utente con timeout
# Mostra un prompt all'utente e attende input con timeout
# Parametri:
#   $1 - Testo del prompt
#   $2 - Valore predefinito
#   $3 - Timeout in secondi
prompt_with_timeout() {
    local prompt="$1"
    local default="$2"
    local timeout="$3"
    local result
    
    # Mostra prompt con valore predefinito e timeout
    echo -ne "${prompt} [${default}] (timeout ${timeout}s): "
    
    # Leggi input con timeout
    read -t "${timeout}" result
    
    # Se nessun input, usa valore predefinito
    if [[ -z "${result}" ]]; then
        echo "${default}"
        return 0
    fi
    
    # Altrimenti, restituisci l'input dell'utente
    echo "${result}"
    return 0
}

# Funzione: Verifica spazio su disco
# Controlla se c'è abbastanza spazio su disco per l'installazione
# Parametri:
#   $1 - Spazio richiesto in MB
#   $2 - Punto di mount da verificare
#   $3 - File di log
check_disk_space() {
    local required_mb="$1"
    local mount_point="$2"
    local log_file="$3"
    
    log "INFO" "Verifica spazio su disco per ${mount_point}..." "${log_file}"
    
    # Ottieni spazio disponibile in MB
    local available_mb=$(df -m "${mount_point}" | awk 'NR==2 {print $4}')
    
    # Verifica se lo spazio è sufficiente
    if [[ "${available_mb}" -lt "${required_mb}" ]]; then
        log "ERROR" "Spazio su disco insufficiente: ${available_mb}MB disponibili, ${required_mb}MB richiesti" "${log_file}"
        return 1
    fi
    
    log "SUCCESS" "Spazio su disco sufficiente: ${available_mb}MB disponibili" "${log_file}"
    return 0
}

# ============================================================================== #
# SEZIONE: Controllo esecuzione diretta
# ============================================================================== #

# Questo blocco impedisce l'esecuzione diretta di questo script
# Il file è progettato per essere importato da altri script, non eseguito direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Questo script è una libreria e non dovrebbe essere eseguito direttamente."
    echo "Deve essere importato da altri script tramite 'source'."
    exit 1
fi
