#!/bin/bash
# wpinstaller/scripts/0_launcher.sh
# MENU PRINCIPALE CON GESTIONE ERRORI MIGLIORATA

set -euo pipefail
trap 'echo "Errore a linea $LINENO"; exit 1' ERR

# Percorsi file
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_FILE="${SCRIPT_DIR}/../config/wp_installer.cfg"
LOG_DIR="${SCRIPT_DIR}/../logs"

# Verifica root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[0;31mQuesto script richiede privilegi di root. Eseguire con sudo.\033[0m"
    exit 1
fi

# Funzioni
show_banner() {
    clear
    echo -e "\033[1;36m"
    echo " ██████╗ ██████╗ ███████╗██████╗ "
    echo "██╔═══██╗██╔══██╗██╔════╝██╔══██╗"
    echo "██║   ██║██████╔╝█████╗  ██████╔╝"
    echo "██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗"
    echo "╚██████╔╝██║     ███████╗██║  ██║"
    echo " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝"
    echo -e "\033[0m"
    echo " WordPress Installer v2.0"
    echo "========================="
}

run_script() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}"
    local log_file="${LOG_DIR}/${script_name%.*}.log"
    
    if [ ! -f "$script_path" ]; then
        echo -e "\033[0;31m[ERRORE] File ${script_name} non trovato\033[0m"
        return 1
    fi
    
    echo -e "\n\033[1;34m[ESECUZIONE] ${script_name}\033[0m"
    echo -e "Log dettagliato: ${log_file}\n"
    
    if ! bash -x "$script_path" 2>&1 | tee "$log_file"; then
        echo -e "\033[0;31m[ERRORE] Script ${script_name} fallito (codice $?)\033[0m"
        echo -e "\033[0;33mConsultare il log per dettagli: ${log_file}\033[0m"
        return 1
    fi
}

full_installation() {
    local steps=(
        "1_system_setup.sh"
        "2_mysql_setup.sh"
        "3_wordpress_setup.sh"
        "4_ssl_setup.sh"
        "5_final_config.sh"
    )
    
    for step in "${steps[@]}"; do
        if ! run_script "$step"; then
            echo -e "\033[0;31m[INSTALLAZIONE INTERROTTA]\033[0m"
            exit 1
        fi
    done
}

# Main
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

while true; do
    show_banner
    echo -e "\033[1;37mMENU PRINCIPALE:\033[0m"
    echo "1) Installazione Completa"
    echo "2) Configura Sistema"
    echo "3) Configura Database"
    echo "4) Installa WordPress"
    echo "5) Configura SSL"
    echo "6) Verifica Finale"
    echo "7) Esci"
    echo -ne "\n\033[1;37mSeleziona opzione: \033[0m"
    
    read -r choice
    case $choice in
        1) full_installation ;;
        2) run_script "1_system_setup.sh" ;;
        3) run_script "2_mysql_setup.sh" ;;
        4) run_script "3_wordpress_setup.sh" ;;
        5) run_script "4_ssl_setup.sh" ;;
        6) run_script "5_final_config.sh" ;;
        7) exit 0 ;;
        *) echo -e "\033[0;31mOpzione non valida!\033[0m" ;;
    esac
    
    read -rp "Premi INVIO per continuare..." -n 1
done