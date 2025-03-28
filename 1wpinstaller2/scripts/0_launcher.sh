#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    0_launcher.sh                                      :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.it          #
#                                                                                #
# ****************************************************************************** #

# ============================================================================== #
# CONFIGURAZIONE PATH
# ============================================================================== #

# Determina il percorso assoluto dello script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Percorso base del progetto (una directory sopra scripts/)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Percorsi configurazione
CONFIG_DIR="${PROJECT_ROOT}/config"
WP_CONFIG="${CONFIG_DIR}/wp_installer.cfg"
ENV_CONFIG="${CONFIG_DIR}/env.cfg"

# ============================================================================== #
# FUNZIONI DI UTILITÀ
# ============================================================================== #

# Verifica la presenza dei file essenziali
check_requirements() {
    local missing=0
    
    # Verifica file di configurazione
    if [ ! -f "$WP_CONFIG" ]; then
        echo -e "\033[0;31m❌ File wp_installer.cfg mancante in ${CONFIG_DIR}\033[0m"
        missing=$((missing+1))
    fi
    
    if [ ! -f "$ENV_CONFIG" ]; then
        echo -e "\033[0;31m❌ File env.cfg mancante in ${CONFIG_DIR}\033[0m"
        missing=$((missing+1))
    fi
    
    # Verifica permessi root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\033[0;31m❌ Lo script richiede permessi root. Usa: sudo $0\033[0m"
        missing=$((missing+1))
    fi
    
    return $missing
}

# Carica le configurazioni
load_config() {
    if ! source "$WP_CONFIG"; then
        echo -e "\033[0;31m❌ Errore nel file wp_installer.cfg (sintassi non valida)\033[0m" >&2
        exit 1
    fi
    
    if ! source "$ENV_CONFIG"; then
        echo -e "\033[0;31m❌ Errore nel file env.cfg (sintassi non valida)\033[0m" >&2
        exit 1
    fi
}

# ============================================================================== #
# MENU PRINCIPALE
# ============================================================================== #

show_menu() {
    clear
    echo -e "\033[1;36m=== WP-NGINX INSTALLER ===\033[0m"
    echo -e "Ambiente: \033[1;33m${ENV_MODE}\033[0m"
    echo -e "Dominio: \033[1;33m${DOMAIN}\033[0m"
    echo -e "Porta: \033[1;33m${SERVER_PORT}\033[0m"
    echo -e "SSL: \033[1;33m${SSL_TYPE}\033[0m"
    echo ""
    echo "1. Installazione Completa"
    echo "2. Cambia Porta"
    echo "3. Configura SSL"
    echo "4. Verifica Installazione"
    echo "0. Esci"
}

# ============================================================================== #
# MAIN
# ============================================================================== #

# Verifica prerequisiti
if ! check_requirements; then
    exit 1
fi

# Carica configurazioni
load_config

# Loop menu principale
while true; do
    show_menu
    read -p "Scelta: " choice
    
    case $choice in
        1) bash "${SCRIPT_DIR}/1_system_setup.sh" ;;
        2) bash "${SCRIPT_DIR}/2_change_port.sh" ;;
        3) bash "${SCRIPT_DIR}/3_ssl_setup.sh" ;;
        4) bash "${SCRIPT_DIR}/4_verify_install.sh" ;;
        0) exit 0 ;;
        *) echo -e "\033[0;31mScelta non valida!\033[0m" ;;
    esac
    
    read -p "Premi INVIO per continuare..." -r
done