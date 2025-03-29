#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    setup_wpinstaller.sh                               :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Script di servizio per creare la struttura di file e cartelle di wpinstaller
# Questo script si occupa di:
# - Creare la struttura di directory necessaria
# - Copiare i file nei percorsi corretti
# - Impostare i permessi appropriati
# - Preparare l'ambiente per l'esecuzione degli script

# ============================================================================== #
# SEZIONE: Impostazioni di sicurezza per bash
# ============================================================================== #
# Queste impostazioni rendono lo script più robusto e sicuro

# set -e: Termina lo script se un comando restituisce un codice di errore
# set -u: Termina lo script se viene utilizzata una variabile non definita
# set -o pipefail: Considera fallito un pipeline se uno qualsiasi dei comandi fallisce
set -euo pipefail

# ============================================================================== #
# SEZIONE: Definizione colori per output
# ============================================================================== #

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================== #
# SEZIONE: Funzioni di utilità
# ============================================================================== #

# Funzione: Mostra messaggio di errore e termina lo script
error_exit() {
    echo -e "${RED}${BOLD}ERRORE:${NC} $1" >&2
    exit 1
}

# Funzione: Mostra messaggio di successo
success_msg() {
    echo -e "${GREEN}${BOLD}SUCCESSO:${NC} $1"
}

# Funzione: Mostra messaggio informativo
info_msg() {
    echo -e "${BLUE}${BOLD}INFO:${NC} $1"
}

# Funzione: Mostra messaggio di avviso
warning_msg() {
    echo -e "${YELLOW}${BOLD}AVVISO:${NC} $1"
}

# Funzione: Mostra banner
show_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "██╗    ██╗██████╗ ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗ "
    echo "██║    ██║██╔══██╗██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗"
    echo "██║ █╗ ██║██████╔╝██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝"
    echo "██║███╗██║██╔═══╝ ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗"
    echo "╚███╔███╔╝██║     ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║"
    echo " ╚══╝╚══╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${BOLD}Installatore WordPress Automatico${NC}"
    echo -e "${BOLD}Autore:${NC} thenizix@protonmail.com"
    echo -e "${BOLD}Data:${NC} $(date +%d/%m/%Y)"
    echo -e "${BOLD}Versione:${NC} 1.0.0"
    echo ""
}

# ============================================================================== #
# SEZIONE: Funzioni principali
# ============================================================================== #

# Funzione: Crea struttura directory
create_directory_structure() {
    info_msg "Creazione struttura directory..."
    
    # Directory principale
    mkdir -p wpinstaller
    
    # Sottodirectory
    mkdir -p wpinstaller/config
    mkdir -p wpinstaller/scripts/lib
    mkdir -p wpinstaller/templates
    mkdir -p wpinstaller/logs
    mkdir -p wpinstaller/state
    
    success_msg "Struttura directory creata con successo"
}

# Funzione: Copia file
copy_files() {
    info_msg "Copia file nei percorsi corretti..."
    
    # File principali
    cp wpinstaller_install.sh wpinstaller/install.sh || error_exit "Impossibile copiare install.sh"
    cp wpinstaller_config.cfg wpinstaller/config/config.cfg || error_exit "Impossibile copiare config.cfg"
    
    # Librerie
    cp wpinstaller_common.sh wpinstaller/scripts/lib/common.sh || error_exit "Impossibile copiare common.sh"
    cp wpinstaller_environment.sh wpinstaller/scripts/lib/environment.sh || error_exit "Impossibile copiare environment.sh"
    cp wpinstaller_security.sh wpinstaller/scripts/lib/security.sh || error_exit "Impossibile copiare security.sh"
    cp wpinstaller_services.sh wpinstaller/scripts/lib/services.sh || error_exit "Impossibile copiare services.sh"
    
    # Script principali
    cp wpinstaller_0_launcher.sh wpinstaller/scripts/0_launcher.sh || error_exit "Impossibile copiare 0_launcher.sh"
    cp wpinstaller_1_system_setup.sh wpinstaller/scripts/1_system_setup.sh || error_exit "Impossibile copiare 1_system_setup.sh"
    cp wpinstaller_2_mysql_setup.sh wpinstaller/scripts/2_mysql_setup.sh || error_exit "Impossibile copiare 2_mysql_setup.sh"
    cp wpinstaller_3_wordpress_setup.sh wpinstaller/scripts/3_wordpress_setup.sh || error_exit "Impossibile copiare 3_wordpress_setup.sh"
    cp wpinstaller_4_ssl_setup.sh wpinstaller/scripts/4_ssl_setup.sh || error_exit "Impossibile copiare 4_ssl_setup.sh"
    cp wpinstaller_5_final_config.sh wpinstaller/scripts/5_final_config.sh || error_exit "Impossibile copiare 5_final_config.sh"
    
    # Template
    cp wpinstaller_nginx-local.conf wpinstaller/templates/nginx-local.conf || error_exit "Impossibile copiare nginx-local.conf"
    cp wpinstaller_nginx-prod.conf wpinstaller/templates/nginx-prod.conf || error_exit "Impossibile copiare nginx-prod.conf"
    
    success_msg "File copiati con successo"
}

# Funzione: Imposta permessi
set_permissions() {
    info_msg "Impostazione permessi..."
    
    # Permessi esecuzione per script
    chmod 755 wpinstaller/install.sh
    chmod 755 wpinstaller/scripts/*.sh
    chmod 755 wpinstaller/scripts/lib/*.sh
    
    # Permessi lettura per file di configurazione e template
    chmod 644 wpinstaller/config/config.cfg
    chmod 644 wpinstaller/templates/*.conf
    
    # Permessi directory
    chmod 755 wpinstaller
    chmod 755 wpinstaller/config
    chmod 755 wpinstaller/scripts
    chmod 755 wpinstaller/scripts/lib
    chmod 755 wpinstaller/templates
    chmod 750 wpinstaller/logs
    chmod 750 wpinstaller/state
    
    success_msg "Permessi impostati con successo"
}

# Funzione: Crea file tree
create_file_tree() {
    info_msg "Creazione file tree..."
    
    # Crea file tree
    find wpinstaller -type f -o -type d | sort > wpinstaller/file_tree.txt
    
    success_msg "File tree creato con successo"
}

# Funzione: Crea archivio zip
create_zip_archive() {
    info_msg "Creazione archivio zip..."
    
    # Crea archivio zip
    zip -r wpinstaller.zip wpinstaller
    
    success_msg "Archivio zip creato con successo: wpinstaller.zip"
}

# Funzione: Avvia server web temporaneo
start_temp_web_server() {
    info_msg "Avvio server web temporaneo..."
    
    # Crea directory per server web
    mkdir -p web_share
    cp wpinstaller.zip web_share/
    
    # Avvia server web Python in background
    cd web_share && python3 -m http.server 8000 &
    SERVER_PID=$!
    
    # Attendi avvio server
    sleep 2
    
    success_msg "Server web temporaneo avviato sulla porta 8000"
    info_msg "URL per il download: http://localhost:8000/wpinstaller.zip"
    info_msg "Se stai utilizzando un server remoto, sostituisci 'localhost' con l'indirizzo IP o il nome host del server"
    
    # Mostra URL pubblico se disponibile
    if command -v curl &> /dev/null; then
        PUBLIC_IP=$(curl -s ifconfig.me)
        if [ -n "$PUBLIC_IP" ]; then
            info_msg "URL pubblico: http://$PUBLIC_IP:8000/wpinstaller.zip"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}${BOLD}Premi CTRL+C per terminare il server web quando hai finito${NC}"
    
    # Attendi input utente
    wait $SERVER_PID
}

# ============================================================================== #
# SEZIONE: Funzione principale
# ============================================================================== #

# Funzione: Main
main() {
    # Mostra banner
    show_banner
    
    # Verifica presenza file necessari
    for file in wpinstaller_install.sh wpinstaller_config.cfg wpinstaller_common.sh wpinstaller_environment.sh wpinstaller_security.sh wpinstaller_services.sh wpinstaller_0_launcher.sh wpinstaller_1_system_setup.sh wpinstaller_2_mysql_setup.sh wpinstaller_3_wordpress_setup.sh wpinstaller_4_ssl_setup.sh wpinstaller_5_final_config.sh wpinstaller_nginx-local.conf wpinstaller_nginx-prod.conf; do
        if [ ! -f "$file" ]; then
            error_exit "File $file non trovato"
        fi
    done
    
    # Crea struttura directory
    create_directory_structure
    
    # Copia file
    copy_files
    
    # Imposta permessi
    set_permissions
    
    # Crea file tree
    create_file_tree
    
    # Crea archivio zip
    create_zip_archive
    
    # Chiedi all'utente se vuole avviare il server web temporaneo
    echo ""
    echo -e "${CYAN}${BOLD}Vuoi avviare un server web temporaneo per scaricare l'archivio zip?${NC}"
    echo -n "Questa operazione avvierà un server web sulla porta 8000 [s/N]: "
    read -r response
    
    if [[ "${response}" =~ ^[Ss]$ ]]; then
        start_temp_web_server
    else
        info_msg "Server web temporaneo non avviato"
        info_msg "L'archivio zip è disponibile in: $(pwd)/wpinstaller.zip"
    fi
    
    echo ""
    success_msg "Setup completato con successo"
    echo -e "${BOLD}Per utilizzare wpinstaller:${NC}"
    echo "1. Estrai l'archivio zip"
    echo "2. Accedi alla directory wpinstaller"
    echo "3. Esegui ./install.sh come root"
    echo ""
}

# ============================================================================== #
# SEZIONE: Esecuzione principale
# ============================================================================== #

# Esegui la funzione principale
main
