#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    1_system_setup.sh                                   :+:      :+:    :+:     #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

# ============================================================================== #
#                          CONFIGURAZIONE INIZIALE DEL SISTEMA                   #
# ============================================================================== #
# Questo script prepara il sistema base con:
# 1. Verifica connessione internet
# 2. Configurazione DNS fallback
# 3. Pulizia installazioni precedenti
# 4. Installazione pacchetti base (Nginx, PHP, MariaDB)
# ============================================================================== #

# Caricamento configurazioni condivise
source $(dirname "$0")/wp_installer.cfg

# ============================================================================== #
#                          IMPOSTAZIONI COLORI E FUNZIONI                        #
# ============================================================================== #
RED='\033[0;31m'    # Colore per errori
GREEN='\033[0;32m'  # Colore per successi
YELLOW='\033[1;33m' # Colore per avvisi
NC='\033[0m'        # Reset colore

# Funzione per verificare l'esito dei comandi
_check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FALLITO${NC}"
        exit 1
    fi
}

# ============================================================================== #
#                          VERIFICA CONNESSIONE INTERNET                         #
# ============================================================================== #
echo -n "Verifica connessione internet... "
ping -c 1 google.com >/dev/null 2>&1 || {
    # Se la connessione fallisce, configura DNS alternativi
    echo -e "${YELLOW}\nConfigurazione DNS alternativi...${NC}"
    
    # Backup del file resolv.conf esistente
    cp /etc/resolv.conf /etc/resolv.conf.bak
    
    # Aggiunta server DNS di Google e Cloudflare
    for dns in "8.8.8.8" "1.1.1.1"; do
        if ! grep -q "$dns" /etc/resolv.conf; then
            echo "nameserver $dns" >> /etc/resolv.conf
        fi
    done
    
    # Verifica nuovamente la connessione
    ping -c 1 google.com >/dev/null 2>&1 || {
        echo -e "${RED}Nessuna connessione internet disponibile${NC}"
        exit 1
    }
}
_check

# ============================================================================== #
#                          PULIZIA INSTALLAZIONI PRECEDENTI                     #
# ============================================================================== #
echo -e "${YELLOW}\n[1/3] Pulizia sistema...${NC}"

# Arresto servizi se attivi
echo -n "Arresto servizi esistenti... "
systemctl stop nginx php$PHP_VERSION-fpm mariadb 2>/dev/null
_check

# Rimozione pacchetti esistenti
echo -n "Rimozione pacchetti obsoleti... "
apt purge -y nginx* php* mariadb* >/dev/null 2>&1
_check

# Pulizia directory
echo -n "Pulizia file residui... "
rm -rf /var/www/html/* /etc/nginx /etc/php/$PHP_VERSION /var/lib/mysql
_check

# ============================================================================== #
#                          INSTALLAZIONE PACCHETTI BASE                          #
# ============================================================================== #
echo -e "${YELLOW}\n[2/3] Installazione dipendenze...${NC}"

# Aggiornamento repository
echo -n "Aggiornamento lista pacchetti... "
apt update >/dev/null
_check

# Upgrade sistema
echo -n "Aggiornamento sistema... "
apt upgrade -y >/dev/null
_check

# Installazione pacchetti principali
echo -n "Installazione Nginx, MariaDB, PHP... "
apt install -y nginx mariadb-server php$PHP_VERSION-fpm \
               php$PHP_VERSION-mysql php$PHP_VERSION-curl \
               php$PHP_VERSION-gd php$PHP_VERSION-mbstring \
               php$PHP_VERSION-xml php$PHP_VERSION-zip >/dev/null
_check

# ============================================================================== #
#                          CONFIGURAZIONE SERVIZI                                #
# ============================================================================== #
echo -e "${YELLOW}\n[3/3] Configurazione servizi...${NC}"

# Abilitazione servizi
echo -n "Abilitazione servizi... "
systemctl enable --now nginx mariadb php$PHP_VERSION-fpm >/dev/null
_check

# Verifica stato servizi
echo -n "Verifica stato Nginx... "
systemctl is-active --quiet nginx
_check

echo -n "Verifica stato MariaDB... "
systemctl is-active --quiet mariadb
_check

echo -n "Verifica stato PHP-FPM... "
systemctl is-active --quiet php$PHP_VERSION-fpm
_check

# ============================================================================== #
#                          FINE SCRIPT                                           #
# ============================================================================== #
echo -e "${GREEN}\nFase 1 completata con successo!${NC}"
echo -e "Procedi con l'esecuzione di: ${YELLOW}./2_mysql_setup.sh${NC}"