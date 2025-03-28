#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    5_final_config.sh                                 :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.it          #
#                                                                                #
# ****************************************************************************** #

# Configurazioni
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR="${SCRIPT_DIR}/../config"

# Caricamento configurazioni
source "${CONFIG_DIR}/wp_installer.cfg" || {
    echo -e "\033[0;31m❌ Errore nel caricamento della configurazione\033[0m" >&2
    exit 1
}

# Verifica permessi root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[0;31m❌ Lo script deve essere eseguito come root!\033[0m" >&2
    exit 1
fi

# Funzioni
check_services() {
    local services=("nginx" "mariadb" "php${PHP_VERSION}-fpm")
    local all_ok=true
    
    for service in "${services[@]}"; do
        if ! systemctl is-active "$service" >/dev/null; then
            echo -e "\033[0;31m❌ Servizio ${service} non attivo!\033[0m" >&2
            all_ok=false
        fi
    done
    
    if ! "$all_ok"; then
        return 1
    fi
}

check_wordpress() {
    if ! wp core is-installed --path="${WP_DIR}"; then
        echo -e "\033[0;31m❌ WordPress non sembra essere installato correttamente!\033[0m" >&2
        return 1
    fi
}

check_ssl() {
    if [ "$SSL_TYPE" != "none" ]; then
        if [ "$SSL_TYPE" = "letsencrypt" ]; then
            if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
                echo -e "\033[0;31m❌ Certificato Let's Encrypt non trovato!\033[0m" >&2
                return 1
            fi
        elif [ "$SSL_TYPE" = "selfsigned" ]; then
            if [ ! -f "/etc/ssl/certs/nginx-selfsigned.crt" ]; then
                echo -e "\033[0;31m❌ Certificato self-signed non trovato!\033[0m" >&2
                return 1
            fi
        fi
        
        # Verifica connessione HTTPS
        if ! curl -sSk "https://${DOMAIN}" >/dev/null 2>&1; then
            echo -e "\033[0;31m❌ Connessione HTTPS non funzionante!\033[0m" >&2
            return 1
        fi
    fi
}

show_summary() {
    echo -e "\n\033[1;36m=== Riepilogo Configurazione ===\033[0m"
    echo -e "\033[1;34mDominio:\033[0m ${DOMAIN}"
    echo -e "\033[1;34mPorta:\033[0m ${SERVER_PORT}"
    echo -e "\033[1;34mAmbiente:\033[0m ${ENV_MODE}"
    echo -e "\033[1;34mSSL:\033[0m ${SSL_TYPE}"
    echo -e "\033[1;34mPHP Version:\033[0m ${PHP_VERSION}"
    echo -e "\033[1;34mPercorso WordPress:\033[0m ${WP_DIR}"
    
    if [ "$ENV_MODE" = "local" ]; then
        echo -e "\n\033[1;33mAccesso WordPress:\033[0m http://${DOMAIN}:${SERVER_PORT}"
    else
        if [ "$SSL_TYPE" != "none" ]; then
            echo -e "\n\033[1;33mAccesso WordPress:\033[0m https://${DOMAIN}"
        else
            echo -e "\n\033[1;33mAccesso WordPress:\033[0m http://${DOMAIN}"
        fi
    fi
    
    echo -e "\n\033[1;33mCredenziali Amministratore:\033[0m"
    echo -e "Utente: admin"
    echo -e "Password: admin"
    echo -e "\033[1;31m⚠ Cambiare le credenziali dopo il primo accesso!\033[0m"
    
    if [ -f "/root/mysql_credentials.txt" ]; then
        echo -e "\n\033[1;33mCredenziali MySQL salvate in:\033[0m /root/mysql_credentials.txt"
    fi
}

main() {
    echo -e "\033[1;36m=== Verifica Finale ===\033[0m"
    
    local all_checks_passed=true
    
    if ! check_services; then
        all_checks_passed=false
    fi
    
    if ! check_wordpress; then
        all_checks_passed=false
    fi
    
    if [ "$SSL_TYPE" != "none" ] && ! check_ssl; then
        all_checks_passed=false
    fi
    
    if "$all_checks_passed"; then
        echo -e "\033[0;32m✅ Tutti i controlli superati con successo!\033[0m"
        show_summary
    else
        echo -e "\033[0;31m❌ Alcuni controlli hanno fallito!\033[0m" >&2
        exit 1
    fi
}

main