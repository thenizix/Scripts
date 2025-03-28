#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    5_final_config.sh                                :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@student.42.fr>          +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/06/01 17:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/06/11 10:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# ============================================================================== #
# INIZIALIZZAZIONE
# ============================================================================== #
set -eo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/../logs/final_check.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================================== #
# FUNZIONI DI VERIFICA
# ============================================================================== #

verifica_servizi() {
    local servizi=("nginx" "mariadb" "php${PHP_VERSION}-fpm")
    for servizio in "${servizi[@]}"; do
        if grep -qi microsoft /proc/version; then
            service "$servizio" status | grep -q 'active (running)' || return 1
        else
            systemctl is-active "$servizio" >/dev/null || return 1
        fi
    done
}

# ============================================================================== #
# MAIN
# ============================================================================== #
{
    echo "🔍 Inizio verifica finale"
    
    # Verifica servizi
    if ! verifica_servizi; then
        echo "❌ Servizi non attivi"
        exit 1
    fi
    
    # Verifica WordPress
    if ! sudo -u www-data wp core is-installed --path="${WP_DIR}"; then
        echo "❌ WordPress non installato"
        exit 1
    fi
    
    # Verifica SSL se abilitato
    if [ "$SSL_TYPE" != "none" ]; then
        if ! curl -Isk "https://${DOMAIN}" | grep -q "HTTP/2 200"; then
            echo "❌ Connessione HTTPS fallita"
            exit 1
        fi
    fi
    
    echo "✅ Tutti i controlli superati!"
    echo "🌍 Sito accessibile all'indirizzo: $([ "$SSL_TYPE" != "none" ] && echo "https" || echo "http")://${DOMAIN}"
} 2>&1 | tee -a "$LOG_FILE"
