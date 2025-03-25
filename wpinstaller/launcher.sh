#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    launcher.sh                                        :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

# Configurazione colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Percorsi script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_FILE="$SCRIPT_DIR/wp_install.log"

# Lista script in ordine di esecuzione
SCRIPTS=(
    "1_system_setup.sh"
    "2_mysql_setup.sh"
    "3_wordpress_setup.sh"
    "4_ssl_setup.sh"
    "5_final_config.sh"
    "6_letsencrypt.sh"
)

# Funzione per eseguire gli script
run_script() {
    local script="$1"
    echo -e "\n${BLUE}▶ Esecuzione di $script...${NC}"
    
    if [ ! -f "$script" ]; then
        echo -e "${RED}❌ Script $script non trovato!${NC}"
        return 1
    fi
    
    # Esegui in subshell per catturare meglio gli errori
    (bash "$script")
    local status=$?
    
    if [ $status -ne 0 ]; then
        echo -e "${RED}❌ Errore durante $script (status: $status)${NC}"
        echo -e "${YELLOW}ℹ Consulta il log: $LOG_FILE${NC}"
        return $status
    fi
    
    return 0
}

full_installation() {
    echo -e "\n${BLUE}🚀 INIZIO INSTALLAZIONE COMPLETA 🚀${NC}"
    
    # Esegui gli script base
    for script in "1_system_setup.sh" "2_mysql_setup.sh" "3_wordpress_setup.sh"; do
        if ! run_script "$script"; then
            echo -e "${RED}❌ Installazione interrotta!${NC}"
            exit 1
        fi
    done
    
    # Chiedi all'utente se vuole configurare SSL
    read -p "Configurare SSL? [s/n]: " ssl_choice
    case "$ssl_choice" in
        [sS]*) run_script "4_ssl_setup.sh" ;;
        *) echo -e "${YELLOW}ℹ SSL non configurato${NC}" ;;
    esac
    
    # Configurazioni finali
    run_script "5_final_config.sh"
    
    echo -e "\n${GREEN}✅ INSTALLAZIONE COMPLETATA!${NC}"
    echo -e "${YELLOW}ℹ Log completo: $LOG_FILE${NC}"
    echo -e "\n${BLUE}🔗 URL Admin: http://${DOMAIN}/wp-admin${NC}"
}