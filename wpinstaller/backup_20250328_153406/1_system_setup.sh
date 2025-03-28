#!/bin/bash
# CONFIGURAZIONE INIZIALE DEL SISTEMA

# Caricamento configurazione
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/system_setup.log"

# Funzione: Gestione servizi con timeout
manage_service() {
    local service_name=$1
    local action=$2
    local timeout=300
    local interval=5
    local elapsed=0

    echo "[SERVIZIO] ${service_name} -> ${action}" | tee -a "$LOG_FILE"
    
    # Comando specifico per WSL
    if grep -qi "microsoft" /proc/version; then
        sudo service "${service_name}" "${action}"
    else
        sudo systemctl "${action}" "${service_name}"
    fi

    # Attesa stato servizio
    while [ $elapsed -lt $timeout ]; do
        if verify_service_active "${service_name}"; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo -e "\033[0;31m[ERRORE] Timeout servizio ${service_name}\033[0m" | tee -a "$LOG_FILE"
    return 1
}

# Funzione: Verifica stato servizio
verify_service_active() {
    local service_name=$1
    if grep -qi "microsoft" /proc/version; then
        service "${service_name}" status | grep -q "active (running)"
    else
        systemctl is-active "${service_name}" >/dev/null 2>&1
    fi
}

# Main process
{
    echo "=== INIZIO CONFIGURAZIONE SISTEMA ==="
    
    # Aggiornamento pacchetti
    echo "Aggiornamento repository..." | tee -a "$LOG_FILE"
    sudo apt-get update -y | tee -a "$LOG_FILE"
    
    # Installazione componenti base
    echo "Installazione pacchetti..." | tee -a "$LOG_FILE"
    sudo apt-get install -y \
        nginx \
        mariadb-server \
        "php${PHP_VERSION}-fpm" \
        "php${PHP_VERSION}-mysql" \
        "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-gd" \
        "php${PHP_VERSION}-xml" | tee -a "$LOG_FILE"
    
    # Avvio servizi
    manage_service "mariadb" "start"
    manage_service "php${PHP_VERSION}-fpm" "start"
    
    echo "=== CONFIGURAZIONE COMPLETATA ==="
} 2>&1 | tee -a "$LOG_FILE"
