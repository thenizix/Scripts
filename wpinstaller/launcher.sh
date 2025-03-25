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

# ============================================================================== #
#                          LAUNCHER INSTALLAZIONE AUTOMATICA                     #
# ============================================================================== #
# Questo script gestisce l'esecuzione sequenziale di tutti gli script            #
# di installazione con:                                                          #
# 1. Verifica prerequisiti                                                       #
# 2. Scelta tipo SSL                                                             #
# 3. Esecuzione automatica                                                       #
# 4. Log dettagliato                                                             #
# ============================================================================== #

# ============================================================================== #
#                          CONFIGURAZIONE INIZIALE                               #
# ============================================================================== #
SCRIPT_DIR=$(dirname "$0")
CONFIG_FILE="${SCRIPT_DIR}/wp_installer.cfg"
LOG_FILE="${SCRIPT_DIR}/wp_install.log"

# ============================================================================== #
#                          IMPOSTAZIONI COLORI E FUNZIONI                        #
# ============================================================================== #
RED='\033[0;31m'    # Colore per errori
GREEN='\033[0;32m'  # Colore per successi
YELLOW='\033[1;33m' # Colore per avvisi
NC='\033[0m'        # Reset colore

# Funzione per loggare su file e terminale
_log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Funzione per eseguire gli script con controllo errori
_run_script() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}"
    
    _log "${YELLOW}Avvio ${script_name}...${NC}"
    
    if [ ! -f "$script_path" ]; then
        _log "${RED}ERRORE: Script ${script_name} non trovato${NC}"
        return 1
    fi
    
    if ! bash "$script_path" 2>&1 | tee -a "$LOG_FILE"; then
        _log "${RED}ERRORE durante l'esecuzione di ${script_name}${NC}"
        return 1
    fi
    
    _log "${GREEN}${script_name} completato con successo${NC}"
    return 0
}

# ============================================================================== #
#                          VERIFICA PREREQUISITI                                 #
# ============================================================================== #
clear
echo -e "${GREEN}
===============================================================================
                INSTALLAZIONE AUTOMATICA WORDPRESS SU NGINX
===============================================================================
${NC}"

# Verifica root
if [ "$(id -u)" -ne 0 ]; then
    _log "${RED}ERRORE: Lo script deve essere eseguito come root${NC}"
    exit 1
fi

# Verifica configurazione
if [ ! -f "$CONFIG_FILE" ]; then
    _log "${RED}ERRORE: File di configurazione wp_installer.cfg mancante${NC}"
    exit 1
fi

# ============================================================================== #
#                          SCELTA TIPO INSTALLAZIONE                             #
# ============================================================================== #
_log "${YELLOW}Seleziona il tipo di installazione:${NC}"
echo "1) Sviluppo (SSL self-signed)"
echo "2) Produzione (Let's Encrypt)"
read -p "Scelta [1-2]: " install_type

case "$install_type" in
    1) ssl_script="4_ssl_setup.sh" ;;
    2) ssl_script="6_letsencrypt.sh" ;;
    *) 
        _log "${RED}Scelta non valida, uso SSL self-signed${NC}"
        ssl_script="4_ssl_setup.sh"
        ;;
esac

# ============================================================================== #
#                          ESEGUZIONE SCRIPTS                                    #
# ============================================================================== #
_log "${GREEN}Inizio installazione...${NC}"

scripts=(
    "1_system_setup.sh"
    "2_mysql_setup.sh"
    "3_wordpress_setup.sh"
    "$ssl_script"
    "5_final_config.sh"
)

for script in "${scripts[@]}"; do
    if ! _run_script "$script"; then
        _log "${RED}Installazione interrotta per errore in ${script}${NC}"
        _log "Consultare il log completo: ${YELLOW}${LOG_FILE}${NC}"
        exit 1
    fi
done

# ============================================================================== #
#                          MESSAGGIO FINALE                                      #
# ============================================================================== #
_log "${GREEN}
===============================================================================
                INSTALLAZIONE COMPLETATA CON SUCCESSO!
===============================================================================
${NC}"

# Carica le variabili per il report finale
source "$CONFIG_FILE"

_log "ACCESSO AL SITO: ${YELLOW}https://${DOMAIN}${NC}"
_log "CREDENZIALI DATABASE:"
_log "  - Database: ${YELLOW}${MYSQL_WP_DB}${NC}"
_log "  - Utente: ${YELLOW}${MYSQL_WP_USER}${NC}"
_log "  - Password: ${YELLOW}${MYSQL_WP_PASS}${NC}"
_log ""
_log "FILE IMPORTANTI:"
_log "  - Config Nginx: ${YELLOW}/etc/nginx/sites-available/wordpress${NC}"
_log "  - Config PHP: ${YELLOW}/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf${NC}"
_log "  - Log installazione: ${YELLOW}${LOG_FILE}${NC}"
_log ""
_log "${GREEN}Per problemi consultare il log completo: ${YELLOW}${LOG_FILE}${NC}"