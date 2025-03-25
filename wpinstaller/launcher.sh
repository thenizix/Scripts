#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    launcher.sh                                        :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

# ****************************************************************************** #
#                                                                                #
#                   SCRIPT PRINCIPALE DI INSTALLAZIONE - WSL/Win                 #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee wp_install.log) 2>&1

# Colori per il logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funzione per mostrare il menu principale
show_menu() {
    clear
    echo -e "${BLUE}
===================================================
      INSTALLAZIONE WORDPRESS SU NGINX - WSL/Win
===================================================
${NC}"
    echo -e "${YELLOW}1.${NC} Installa tutto (Nginx, PHP, MySQL, WordPress)"
    echo -e "${YELLOW}2.${NC} Configura solo SSL"
    echo -e "${YELLOW}3.${NC} Ripara installazione"
    echo -e "${YELLOW}4.${NC} Esci"
    echo -e "\n${BLUE}Scelta:${NC} "
}

# Funzione per eseguire gli script con controllo errori
run_script() {
    local script=$1
    echo -e "\n${BLUE}=== Esecuzione $script ===${NC}"
    
    if [ ! -f "$script" ]; then
        echo -e "${RED}❌ Script $script non trovato!${NC}"
        return 1
    fi
    
    if ! bash "$script"; then
        echo -e "${RED}❌ Errore durante l'esecuzione di $script${NC}"
        echo -e "${YELLOW}ℹ️  Consulta il file wp_install.log per i dettagli${NC}"
        return 1
    fi
    
    return 0
}

# Funzione per l'installazione completa
full_installation() {
    echo -e "${GREEN}🚀 Inizio installazione completa...${NC}"
    
    local scripts=(
        "1_system_setup.sh"
        "2_mysql_setup.sh"
        "3_wordpress_setup.sh"
    )
    
    # Selezione tipo SSL
    echo -e "\n${BLUE}Seleziona il tipo di SSL:${NC}"
    select ssl_type in "Self-Signed" "Let's Encrypt" "Nessuno"; do
        case $ssl_type in
            "Self-Signed") scripts+=("4_ssl_setup.sh"); break ;;
            "Let's Encrypt") scripts+=("6_letsencrypt.sh"); break ;;
            "Nessuno") break ;;
            *) echo -e "${RED}Scelta non valida!${NC}";;
        esac
    done
    
    scripts+=("5_final_config.sh")
    
    # Esecuzione script in sequenza
    for script in "${scripts[@]}"; do
        if ! run_script "$script"; then
            echo -e "${RED}❌ Installazione interrotta!${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}
===================================================
       INSTALLAZIONE COMPLETATA CON SUCCESSO!
===================================================
${NC}"
    echo -e "${BLUE}🌐 URL:${NC} https://${DOMAIN}"
    echo -e "${BLUE}🔑 Database:${NC} ${MYSQL_WP_USER}/${MYSQL_WP_PASS}"
    echo -e "${BLUE}📂 Directory:${NC} ${WP_DIR}"
    echo -e "\n${YELLOW}ℹ️  Log completo:${NC} $(pwd)/wp_install.log"
}

# Main execution
while true; do
    show_menu
    read choice
    
    case $choice in
        1) full_installation; break ;;
        2) run_script "4_ssl_setup.sh"; break ;;
        3) run_script "5_final_config.sh"; break ;;
        4) exit 0 ;;
        *) echo -e "${RED}Scelta non valida!${NC}"; sleep 1 ;;
    esac
done