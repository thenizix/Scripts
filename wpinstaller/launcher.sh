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

# ================= CONFIGURAZIONE COLORI =================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ================= VARIABILI GLOBALI =================
LOG_FILE="wp_install.log"
SCRIPTS=(
    "1_system_setup.sh"
    "2_mysql_setup.sh"
    "3_wordpress_setup.sh"
    "4_ssl_setup.sh"
    "5_final_config.sh"
    "6_letsencrypt.sh"
)

# ================= FUNZIONI PRINCIPALI =================

# Verifica preliminare prima dell'esecuzione
pre_flight_check() {
    echo -e "${BLUE}🔍 Verifica preliminare...${NC}"
    
    # Verifica permessi root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌ Questo script deve essere eseguito come root!${NC}"
        exit 1
    fi
    
    # Verifica presenza file di configurazione
    if [ ! -f "wp_installer.cfg" ]; then
        echo -e "${RED}❌ File di configurazione wp_installer.cfg mancante!${NC}"
        exit 1
    fi
    
    # Verifica script di installazione
    for script in "${SCRIPTS[@]}"; do
        if [ ! -f "$script" ]; then
            echo -e "${RED}❌ Script $script mancante!${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✅ Tutti i controlli superati${NC}"
}

# Esegue uno script con logging e gestione errori
run_script() {
    local script="$1"
    echo -e "\n${BLUE}▶ Esecuzione di $script...${NC}"
    
    if [ ! -f "$script" ]; then
        echo -e "${RED}❌ Script $script non trovato!${NC}"
        return 1
    fi
    
    if ! bash "$script"; then
        echo -e "${RED}❌ Errore durante l'esecuzione di $script!${NC}"
        echo -e "${YELLOW}ℹ Consulta il file di log $LOG_FILE per i dettagli${NC}"
        return 1
    fi
    
    return 0
}

# Installazione completa
full_installation() {
    echo -e "\n${BLUE}🚀 INIZIO INSTALLAZIONE COMPLETA 🚀${NC}"
    
    for script in "${SCRIPTS[@]}"; do
        if ! run_script "$script"; then
            echo -e "${RED}❌ Installazione interrotta!${NC}"
            exit 1
        fi
    done
    
    echo -e "\n${GREEN}✅ INSTALLAZIONE COMPLETATA CON SUCCESSO!${NC}"
    echo -e "${YELLOW}ℹ Log completo disponibile in $LOG_FILE${NC}"
}

# Configurazione SSL
ssl_setup() {
    echo -e "\n${BLUE}🔐 CONFIGURAZIONE SSL${NC}"
    run_script "4_ssl_setup.sh"
}

# Riparazione installazione
repair_installation() {
    echo -e "\n${BLUE}🔧 RIPARAZIONE INSTALLAZIONE${NC}"
    run_script "5_final_config.sh"
}

# Menu interattivo
show_menu() {
    while true; do
        clear
        echo -e "${BLUE}
===================================================
      INSTALLAZIONE WORDPRESS SU NGINX - WSL/Win
===================================================
${NC}"
        echo -e "${YELLOW}1.${NC} Installazione completa"
        echo -e "${YELLOW}2.${NC} Configurazione SSL"
        echo -e "${YELLOW}3.${NC} Riparazione installazione"
        echo -e "${YELLOW}4.${NC} Uscita"
        echo -ne "\n${BLUE}Scelta: ${NC}"
        
        read -r choice
        case $choice in
            1) full_installation; break ;;
            2) ssl_setup; break ;;
            3) repair_installation; break ;;
            4) exit 0 ;;
            *) echo -e "${RED}Scelta non valida! Riprovare.${NC}"; sleep 1 ;;
        esac
    done
}

# ================= ESECUZIONE PRINCIPALE =================
main() {
    # Reindirizza stdout e stderr al log file
    exec > >(tee -a "$LOG_FILE") 2>&1
    
    pre_flight_check
    show_menu
}

main "$@"