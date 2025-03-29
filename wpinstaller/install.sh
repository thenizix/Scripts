#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    install.sh                                         :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Script principale di installazione WordPress
# Questo script è il punto di ingresso dell'installatore e si occupa di:
# 1. Verificare i privilegi di root
# 2. Creare la struttura delle directory necessarie
# 3. Impostare i permessi corretti
# 4. Avviare il launcher principale

# ============================================================================== #
# SEZIONE: Inizializzazione e verifica ambiente
# ============================================================================== #

# Ottiene il percorso assoluto della directory dello script
# Questo garantisce che lo script funzioni correttamente indipendentemente 
# dalla directory da cui viene eseguito
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Verifica se l'utente è root
# L'installazione richiede privilegi di root per configurare servizi di sistema,
# modificare file di configurazione e impostare permessi
if [[ $EUID -ne 0 ]]; then
    # Messaggio di errore con colore rosso per evidenziare l'importanza
    echo -e "\033[0;31mQuesto script deve essere eseguito come root o con sudo.\033[0m"
    echo -e "\033[0;31mEsempio: sudo ./install.sh\033[0m"
    exit 1
fi

# ============================================================================== #
# SEZIONE: Creazione struttura directory
# ============================================================================== #

# Crea la struttura delle directory se non esiste
# Questa struttura modulare permette una migliore organizzazione del codice
# e una separazione chiara delle responsabilità
echo -e "\033[0;36mCreazione struttura directory...\033[0m"

# Directory di configurazione - contiene tutti i file di configurazione
mkdir -p "${SCRIPT_DIR}/config"

# Directory degli script - contiene tutti gli script di installazione
mkdir -p "${SCRIPT_DIR}/scripts/lib"

# Directory dei template - contiene i template per i file di configurazione
mkdir -p "${SCRIPT_DIR}/templates"

# Directory dei log - contiene tutti i file di log generati durante l'installazione
mkdir -p "${SCRIPT_DIR}/logs"

# Directory dello stato - contiene i file che tengono traccia dello stato dell'installazione
mkdir -p "${SCRIPT_DIR}/state"

# ============================================================================== #
# SEZIONE: Impostazione permessi
# ============================================================================== #

# Imposta i permessi corretti per le directory
# Questo è importante per la sicurezza del sistema
echo -e "\033[0;36mImpostazione permessi...\033[0m"

# Permessi per la directory degli script - esecuzione per tutti
chmod 755 "${SCRIPT_DIR}/scripts"

# Permessi per la directory dei log - accesso limitato
chmod 750 "${SCRIPT_DIR}/logs"

# Permessi per la directory dello stato - accesso limitato
chmod 750 "${SCRIPT_DIR}/state"

# ============================================================================== #
# SEZIONE: Verifica e avvio
# ============================================================================== #

# Verifica se il launcher esiste
# Questo controllo assicura che l'installazione sia stata completata correttamente
if [[ ! -f "${SCRIPT_DIR}/scripts/0_launcher.sh" ]]; then
    echo -e "\033[0;31mFile launcher non trovato. Installazione non completata correttamente.\033[0m"
    echo -e "\033[0;31mAssicurati che tutti i file siano stati estratti correttamente.\033[0m"
    exit 1
fi

# Imposta permessi di esecuzione per tutti gli script
# Questo è necessario per poter eseguire gli script
echo -e "\033[0;36mImpostazione permessi di esecuzione per gli script...\033[0m"
chmod 755 "${SCRIPT_DIR}/scripts"/*.sh
chmod 755 "${SCRIPT_DIR}/scripts/lib"/*.sh

# Avvia il launcher principale
# Utilizziamo exec per sostituire il processo corrente con il launcher
# in modo da non avere processi inutili in background
echo -e "\033[0;32mAvvio del launcher principale...\033[0m"
exec "${SCRIPT_DIR}/scripts/0_launcher.sh"
