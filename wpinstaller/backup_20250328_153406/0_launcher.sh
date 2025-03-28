#!/bin/bash
# MENU PRINCIPALE CON GESTIONE ERRORI MIGLIORATA

# Percorsi file
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_FILE="${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_DIR="/mnt/c/Users/Francy/Documents/GitHub/Scripts/wpinstaller/logs"

# Funzione: Mostra banner ASCII
show_banner() {
    clear
    echo -e "\033[1;36m"
    echo "▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓"
    echo "▓  W P   INSTALLER   ▓"
    echo "▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓"
    echo -e "\033[0m"
}

# Funzione: Esegue script con controllo errori
run_script() {
    local script_path="${SCRIPT_DIR}/$1"
    if [ -f "$script_path" ]; then
        echo -e "\n\033[1;34m[ESECUZIONE] ${1}\033[0m"
        if ! bash "$script_path"; then
            echo -e "\033[0;31m[ERRORE] Script ${1} fallito\033[0m"
            return 1
        fi
    else
        echo -e "\033[0;31m[ERRORE] File ${1} non trovato\033[0m"
        return 1
    fi
}

# Funzione: Installazione completa
full_installation() {
    local steps=(
        "1_system_setup.sh"
        "2_mysql_setup.sh"
        "3_wordpress_setup.sh"
        "4_ssl_setup.sh"
        "5_final_check.sh"
    )
    for step in "${steps[@]}"; do
        if ! run_script "$step"; then
            echo -e "\033[0;31m[ABORT] Installazione interrotta\033[0m"
            exit 1
        fi
    done
}

# Menu interattivo
main_menu() {
    while true; do
        show_banner
        echo -e "\033[1;37mOPZIONI:\033[0m"
        echo "1) Installazione Completa"
        echo "2) Configura Sistema"
        echo "3) Configura Database"
        echo "4) Installa WordPress"
        echo "5) Configura SSL"
        echo "6) Verifica Finale"
        echo "7) Esci"
        echo -ne "\n\033[1;37mSeleziona: \033[0m"
        
        read choice
        case $choice in
            1) full_installation ;;
            2) run_script "1_system_setup.sh" ;;
            3) run_script "2_mysql_setup.sh" ;;
            4) run_script "3_wordpress_setup.sh" ;;
            5) run_script "4_ssl_setup.sh" ;;
            6) run_script "5_final_check.sh" ;;
            7) exit 0 ;;
            *) echo -e "\033[0;31mScelta non valida!\033[0m" ;;
        esac
        read -p "Premi INVIO per continuare..." -r
    done
}

# Avvio applicazione
mkdir -p "$LOG_DIR"
main_menu
