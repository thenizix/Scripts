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
    echo -e "\n=== Esecuzione di $script ===" >> "$LOG_FILE"
    
    if [ ! -f "$script" ]; then
        echo -e "${RED}❌ Script $script non trovato!${NC}"
        echo "ERRORE: Script $script non trovato!" >> "$LOG_FILE"
        return 1
    fi
    
    # Esegui in subshell per catturare meglio gli errori
    (bash "$script" 2>&1 | tee -a "$LOG_FILE")
    local status=$?
    
    if [ $status -ne 0 ]; then
        echo -e "${RED}❌ Errore durante $script (status: $status)${NC}"
        echo -e "${YELLOW}ℹ Consulta il log: $LOG_FILE${NC}"
        return $status
    fi
    
    return 0
}

# Funzione per il menu principale
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║      WP-NGINX AUTO-INSTALLER MENU      ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ 1) Installazione COMPLETA              ║"
    echo "║ 2) Installazione BASE (no SSL)         ║"
    echo "║ 3) Configura SSL Self-Signed           ║"
    echo "║ 4) Configura Let's Encrypt (SSL reale) ║"
    echo "║ 5) Configurazioni FINALI               ║"
    echo "║ 6) Visualizza LOG                      ║"
    echo "║ 0) Esci                                ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Funzione per l'installazione completa
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
    echo -e "\n${YELLOW}ℹ Configurazione SSL${NC}"
    echo "1) SSL Self-Signed (sviluppo)"
    echo "2) Let's Encrypt (produzione)"
    echo "3) Salta configurazione SSL"
    read -p "Scelta [1-3]: " ssl_choice
    
    case "$ssl_choice" in
        1) run_script "4_ssl_setup.sh" ;;
        2) run_script "6_letsencrypt.sh" ;;
        *) echo -e "${YELLOW}ℹ SSL non configurato${NC}" ;;
    esac
    
    # Configurazioni finali
    run_script "5_final_config.sh"
    
    echo -e "\n${GREEN}✅ INSTALLAZIONE COMPLETATA!${NC}"
    echo -e "${YELLOW}ℹ Log completo: $LOG_FILE${NC}"
    echo -e "\n${BLUE}🔗 URL Admin: http://${DOMAIN}/wp-admin${NC}"
}

# Funzione per l'installazione base (senza SSL)
base_installation() {
    echo -e "\n${BLUE}🚀 INIZIO INSTALLAZIONE BASE 🚀${NC}"
    
    for script in "1_system_setup.sh" "2_mysql_setup.sh" "3_wordpress_setup.sh"; do
        if ! run_script "$script"; then
            echo -e "${RED}❌ Installazione interrotta!${NC}"
            exit 1
        fi
    done
    
    echo -e "\n${GREEN}✅ INSTALLAZIONE BASE COMPLETATA!${NC}"
    echo -e "${YELLOW}ℹ Log completo: $LOG_FILE${NC}"
    echo -e "\n${BLUE}🔗 URL Admin: http://${DOMAIN}/wp-admin${NC}"
}

# Main
clear
echo -e "${BLUE}=== WP-NGINX AUTO-INSTALLER ===${NC}"

# Verifica che lo script sia eseguito come root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ Questo script deve essere eseguito come root/sudo!${NC}"
    exit 1
fi

# Carica la configurazione
if [ ! -f "wp_installer.cfg" ]; then
    echo -e "${RED}❌ File di configurazione wp_installer.cfg non trovato!${NC}"
    exit 1
fi
source wp_installer.cfg

# Menu principale
while true; do
    show_menu
    read -p "Scelta [0-6]: " choice
    
    case "$choice" in
        1) full_installation ;;
        2) base_installation ;;
        3) run_script "4_ssl_setup.sh" ;;
        4) run_script "6_letsencrypt.sh" ;;
        5) run_script "5_final_config.sh" ;;
        6) less "$LOG_FILE" ;;
        0) echo -e "${GREEN}Arrivederci!${NC}"; exit 0 ;;
        *) echo -e "${RED}Scelta non valida!${NC}"; sleep 1 ;;
    esac
    
    read -p "Premi INVIO per continuare..." -n 1 -r
done