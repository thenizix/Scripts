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

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Funzione di pre-check globale
pre_flight_check() {
    # Verifica permessi root
    [ "$EUID" -eq 0 ] || { echo -e "${RED}❌ Eseguire come root!${NC}"; exit 1; }
    
    # Verifica file di configurazione
    [ -f "wp_installer.cfg" ] || { echo -e "${RED}❌ File di configurazione mancante!${NC}"; exit 1; }
    
    # Verifica dipendenze base
    command -v nginx >/dev/null || { echo -e "${RED}❌ Nginx non installato!${NC}"; exit 1; }
}


 run_script() {
    local script="$1"
    if [ -f "$script" ]; then
        echo -e "\033[1;36m▶ Esecuzione di $script...\033[0m"
        ./"$script"
    else
        echo -e "\033[0;31m❌ Script $script non trovato!\033[0m"
        exit 1
    fi
}

full_installation() {
    run_script "1_system_setup.sh"
    run_script "2_mysql_setup.sh"
    run_script "3_wordpress_setup.sh"
    run_script "4_ssl_setup.sh"
    run_script "5_final_config.sh"
    run_script "6_letsencrypt.sh"
    echo -e "\033[1;32m✅ Installazione completata con successo!\033[0m"
}
# Menu interattivo migliorato
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
            2) run_script "4_ssl_setup.sh"; break ;;
            3) run_script "5_final_config.sh"; break ;;
            4) exit 0 ;;
            *) echo -e "${RED}Scelta non valida! Riprovare.${NC}"; sleep 1 ;;
        esac
    done
}

pre_flight_check
show_menu