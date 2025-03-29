#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    environment.sh                                     :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Libreria per il rilevamento dell'ambiente di esecuzione
# Questo file contiene funzioni per rilevare il sistema operativo, WSL,
# versioni software e altre caratteristiche dell'ambiente di esecuzione

# ============================================================================== #
# SEZIONE: Rilevamento WSL (Windows Subsystem for Linux)
# ============================================================================== #

# Funzione: Rileva se lo script è in esecuzione in ambiente WSL
# Utilizza diversi metodi per determinare se il sistema è WSL
# Parametri:
#   $1 - File di log
detect_wsl() {
    local log_file="$1"
    
    log "INFO" "Rilevamento ambiente WSL..." "${log_file}"
    
    # Metodo 1: Verifica presenza del file /proc/version con riferimento a Microsoft
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log "INFO" "WSL rilevato (metodo: /proc/version)" "${log_file}"
        return 0
    fi
    
    # Metodo 2: Verifica presenza del file /proc/sys/kernel/osrelease con riferimento a Microsoft
    if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
        log "INFO" "WSL rilevato (metodo: /proc/sys/kernel/osrelease)" "${log_file}"
        return 0
    fi
    
    # Metodo 3: Verifica presenza della directory /mnt/c
    if [[ -d "/mnt/c/Windows" ]]; then
        log "INFO" "WSL rilevato (metodo: /mnt/c/Windows)" "${log_file}"
        return 0
    fi
    
    # Metodo 4: Verifica output di uname -r
    if uname -r | grep -qi microsoft; then
        log "INFO" "WSL rilevato (metodo: uname -r)" "${log_file}"
        return 0
    fi
    
    # Se nessun metodo ha rilevato WSL, assumiamo che non sia WSL
    log "INFO" "WSL non rilevato" "${log_file}"
    return 1
}

# ============================================================================== #
# SEZIONE: Rilevamento distribuzione Linux
# ============================================================================== #

# Funzione: Rileva la distribuzione Linux e la versione
# Imposta le variabili globali DISTRO_NAME e DISTRO_VERSION
# Parametri:
#   $1 - File di log
detect_linux_distribution() {
    local log_file="$1"
    
    log "INFO" "Rilevamento distribuzione Linux..." "${log_file}"
    
    # Inizializza variabili
    DISTRO_NAME="Unknown"
    DISTRO_VERSION="Unknown"
    
    # Metodo 1: Usa lsb_release se disponibile (più accurato)
    if command -v lsb_release &> /dev/null; then
        DISTRO_NAME=$(lsb_release -si)
        DISTRO_VERSION=$(lsb_release -sr)
        log "INFO" "Distribuzione rilevata (metodo: lsb_release): ${DISTRO_NAME} ${DISTRO_VERSION}" "${log_file}"
        return 0
    fi
    
    # Metodo 2: Controlla /etc/os-release (presente nella maggior parte delle distribuzioni moderne)
    if [[ -f "/etc/os-release" ]]; then
        source "/etc/os-release"
        DISTRO_NAME="${NAME}"
        DISTRO_VERSION="${VERSION_ID}"
        log "INFO" "Distribuzione rilevata (metodo: /etc/os-release): ${DISTRO_NAME} ${DISTRO_VERSION}" "${log_file}"
        return 0
    fi
    
    # Metodo 3: Controlla file specifici delle distribuzioni
    if [[ -f "/etc/debian_version" ]]; then
        DISTRO_NAME="Debian"
        DISTRO_VERSION=$(cat /etc/debian_version)
        log "INFO" "Distribuzione rilevata (metodo: /etc/debian_version): ${DISTRO_NAME} ${DISTRO_VERSION}" "${log_file}"
        return 0
    fi
    
    if [[ -f "/etc/redhat-release" ]]; then
        DISTRO_NAME=$(cat /etc/redhat-release | cut -d' ' -f1)
        DISTRO_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
        log "INFO" "Distribuzione rilevata (metodo: /etc/redhat-release): ${DISTRO_NAME} ${DISTRO_VERSION}" "${log_file}"
        return 0
    fi
    
    # Se non siamo riusciti a rilevare la distribuzione
    log "WARNING" "Impossibile rilevare la distribuzione Linux con precisione" "${log_file}"
    return 1
}

# ============================================================================== #
# SEZIONE: Rilevamento comandi di servizio
# ============================================================================== #

# Funzione: Rileva il comando di gestione servizi appropriato
# Imposta la variabile globale SERVICE_CMD
# Parametri:
#   $1 - File di log
detect_service_command() {
    local log_file="$1"
    
    log "INFO" "Rilevamento comando gestione servizi..." "${log_file}"
    
    # Se SERVICE_CMD è già impostato nella configurazione, usalo
    if [[ -n "${SERVICE_CMD:-}" ]]; then
        log "INFO" "Comando servizi già configurato: ${SERVICE_CMD}" "${log_file}"
        return 0
    fi
    
    # Controlla systemctl (systemd)
    if command -v systemctl &> /dev/null; then
        SERVICE_CMD="systemctl"
        log "INFO" "Comando servizi rilevato: systemctl (systemd)" "${log_file}"
        return 0
    fi
    
    # Controlla service (SysV init)
    if command -v service &> /dev/null; then
        SERVICE_CMD="service"
        log "INFO" "Comando servizi rilevato: service (SysV init)" "${log_file}"
        return 0
    fi
    
    # Controlla /etc/init.d (metodo diretto)
    if [[ -d "/etc/init.d" ]]; then
        SERVICE_CMD="init.d"
        log "INFO" "Comando servizi rilevato: /etc/init.d (metodo diretto)" "${log_file}"
        return 0
    fi
    
    # Se non troviamo un comando valido
    log "WARNING" "Impossibile rilevare un comando di gestione servizi valido" "${log_file}"
    SERVICE_CMD="unknown"
    return 1
}

# ============================================================================== #
# SEZIONE: Rilevamento socket MySQL
# ============================================================================== #

# Funzione: Rileva il socket MySQL/MariaDB
# Imposta la variabile globale MYSQL_SOCKET
# Parametri:
#   $1 - File di log
detect_mysql_socket() {
    local log_file="$1"
    
    log "INFO" "Rilevamento socket MySQL/MariaDB..." "${log_file}"
    
    # Se MYSQL_SOCKET è già impostato nella configurazione, usalo
    if [[ -n "${MYSQL_SOCKET:-}" ]]; then
        log "INFO" "Socket MySQL già configurato: ${MYSQL_SOCKET}" "${log_file}"
        return 0
    fi
    
    # Posizioni comuni del socket MySQL/MariaDB
    local socket_locations=(
        "/var/run/mysqld/mysqld.sock"       # Debian/Ubuntu
        "/var/lib/mysql/mysql.sock"         # Red Hat/CentOS
        "/run/mysqld/mysqld.sock"           # Arch Linux
        "/tmp/mysql.sock"                   # macOS, FreeBSD
    )
    
    # Controlla ogni posizione
    for socket in "${socket_locations[@]}"; do
        if [[ -S "${socket}" ]]; then
            MYSQL_SOCKET="${socket}"
            log "INFO" "Socket MySQL rilevato: ${MYSQL_SOCKET}" "${log_file}"
            return 0
        fi
    done
    
    # Se non troviamo un socket valido
    log "WARNING" "Impossibile rilevare il socket MySQL/MariaDB" "${log_file}"
    MYSQL_SOCKET=""
    return 1
}

# ============================================================================== #
# SEZIONE: Rilevamento versione PHP
# ============================================================================== #

# Funzione: Rileva la versione PHP disponibile
# Verifica se la versione PHP specificata è disponibile, altrimenti trova un'alternativa
# Parametri:
#   $1 - File di log
detect_php_version() {
    local log_file="$1"
    
    log "INFO" "Rilevamento versione PHP..." "${log_file}"
    
    # Versione PHP specificata nella configurazione
    local requested_version="${PHP_VERSION:-7.4}"
    
    # Controlla se la versione richiesta è disponibile
    if command -v "php${requested_version}" &> /dev/null || apt-cache show "php${requested_version}" &> /dev/null; then
        log "INFO" "Versione PHP richiesta disponibile: ${requested_version}" "${log_file}"
        PHP_VERSION="${requested_version}"
        return 0
    fi
    
    # Se la versione richiesta non è disponibile, cerca alternative
    log "WARNING" "Versione PHP ${requested_version} non disponibile, ricerca alternative..." "${log_file}"
    
    # Versioni PHP comuni da controllare (dalla più recente alla meno recente)
    local php_versions=("8.3" "8.2" "8.1" "8.0" "7.4" "7.3" "7.2")
    
    for version in "${php_versions[@]}"; do
        if command -v "php${version}" &> /dev/null || apt-cache show "php${version}" &> /dev/null; then
            log "INFO" "Versione PHP alternativa trovata: ${version}" "${log_file}"
            PHP_VERSION="${version}"
            return 0
        fi
    done
    
    # Se non troviamo nessuna versione PHP
    log "WARNING" "Nessuna versione PHP supportata trovata" "${log_file}"
    PHP_VERSION="7.4"  # Valore predefinito fallback
    return 1
}

# ============================================================================== #
# SEZIONE: Inizializzazione ambiente
# ============================================================================== #

# Funzione: Inizializza l'ambiente di esecuzione
# Rileva tutte le caratteristiche dell'ambiente e salva le informazioni
# Parametri: nessuno
init_environment_detection() {
    local log_file="${LOGS_DIR}/environment.log"
    
    # Crea directory log se non esiste
    mkdir -p "${LOGS_DIR}"
    
    log "STEP" "Inizializzazione rilevamento ambiente" "${log_file}"
    
    # Rileva WSL
    IS_WSL=false
    if detect_wsl "${log_file}"; then
        IS_WSL=true
    fi
    
    # Rileva distribuzione Linux
    detect_linux_distribution "${log_file}"
    
    # Rileva comando servizi
    detect_service_command "${log_file}"
    
    # Rileva socket MySQL
    detect_mysql_socket "${log_file}"
    
    # Rileva versione PHP
    detect_php_version "${log_file}"
    
    # Salva le informazioni rilevate nel file di configurazione dell'ambiente
    log "INFO" "Salvataggio informazioni ambiente in ${ENV_CONFIG}" "${log_file}"
    
    cat > "${ENV_CONFIG}" <<EOF
# Configurazione ambiente rilevato automaticamente
# Generato il $(date "+%Y-%m-%d %H:%M:%S")
# NON MODIFICARE MANUALMENTE!

# Informazioni sistema
IS_WSL=${IS_WSL}
DISTRO_NAME="${DISTRO_NAME}"
DISTRO_VERSION="${DISTRO_VERSION}"

# Comandi e percorsi
SERVICE_CMD="${SERVICE_CMD}"
MYSQL_SOCKET="${MYSQL_SOCKET}"
PHP_VERSION="${PHP_VERSION}"
EOF
    
    # Imposta permessi corretti
    chmod 640 "${ENV_CONFIG}"
    
    log "SUCCESS" "Rilevamento ambiente completato" "${log_file}"
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
