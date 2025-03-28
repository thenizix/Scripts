#!/bin/bash
# VERIFICA FINALE

set -euo pipefail
trap 'echo "Errore a linea $LINENO"; exit 1' ERR

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/final_check.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# Funzioni
check_services() {
    local services=("nginx" "mysql" "php${PHP_VERSION}-fpm")
    for service in "${services[@]}"; do
        echo "🔍 Verifica servizio ${service}..." | tee -a "$LOG_FILE"
        if grep -qi "microsoft" /proc/version; then
            if ! service "${service}" status | grep -q "active (running)"; then
                echo "❌ Servizio ${service} non attivo" | tee -a "$LOG_FILE"
                return 1
            fi
        else
            if ! systemctl is-active "${service}" >/dev/null; then
                echo "❌ Servizio ${service} non attivo" | tee -a "$LOG_FILE"
                return 1
            fi
        fi
    done
}

# Main process
{
    echo "=== VERIFICA FINALE ==="

    # Verifica servizi
    check_services || exit 1

    # Verifica WordPress
    echo "🔍 Verifica installazione WordPress..." | tee -a "$LOG_FILE"
    if ! sudo -u www-data wp core is-installed --path="${WP_DIR}"; then
        echo "❌ WordPress non installato correttamente" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Verifica connessione database
    echo "🔍 Verifica connessione database..." | tee -a "$LOG_FILE"
    if ! sudo -u www-data wp db check --path="${WP_DIR}"; then
        echo "❌ Connessione database fallita" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Verifica SSL (se abilitato)
    if [ "${SSL_TYPE}" != "none" ]; then
        echo "🔍 Verifica SSL..." | tee -a "$LOG_FILE"
        if ! curl -Isk "https://${DOMAIN}" | grep -q "HTTP/.* 200"; then
            echo "❌ Connessione HTTPS fallita" | tee -a "$LOG_FILE"
            exit 1
        fi
    fi

    echo "✅ Tutti i controlli superati!" | tee -a "$LOG_FILE"
    echo "🌍 Sito accessibile all'indirizzo: $([ "${SSL_TYPE}" != "none" ] && echo "https" || echo "http")://${DOMAIN}" | tee -a "$LOG_FILE"
}