#!/bin/bash

# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    download_iso_proxmox.sh                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: TheNizix <student@nowhere>                 +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/02/25 10:00:00 by Thenizix         #+#    #+#              #
#    Updated: 2025/02/25 10:00:00 by TheNizix        ###   ########.fr        #
#                                                                              #
# **************************************************************************** #
# ======================================================================
# Script per scaricare file ISO per Proxmox Virtual Environment
# Autore: TheNizix
# Data: 25/02/2025
# Versione: 1.0
# Descrizione: Questo script scarica file ISO di diverse distribuzioni
# Linux direttamente nella directory di storage delle ISO di Proxmox,
# permettendo immediatamente la creazione
# di macchine virtuali tramite l'interfaccia web di pxmx.
# ======================================================================

# ======================================================================
# La directory /var/lib/vz/template/iso è dove Proxmox memorizza
# i file ISO che poi vengono mostrati nell'interfaccia web durante
# la creazione di nuove VM.
# ======================================================================
TARGET_DIR="/var/lib/vz/template/iso"

# ======================================================================
# Verifica dei privilegi di root
# Lo script deve essere eseguito come root per poter scrivere nella
# directory di sistema di Proxmox.
# ======================================================================
if [ "$(id -u)" -ne 0 ]; then
   echo "========================================================="
   echo "ERRORE: Questo script deve essere eseguito come root."
   echo "Usa sudo o esegui come utente root."
   echo "========================================================="
   exit 1
fi

# ======================================================================
# Creazione della directory se non esiste
# Verifica se la directory di destinazione esiste e la crea se serve.
# ======================================================================
if [ ! -d "$TARGET_DIR" ]; then
   echo "========================================================="
   echo "INFO: Creazione della directory $TARGET_DIR..."
   echo "========================================================="
   mkdir -p $TARGET_DIR
fi

# ======================================================================
# Cambia la directory corrente nella directory di destinazione
# In questo modo i file verranno scaricati direttamente nella posizione
# corretta senza necessità di spostarli successivamente.
# ======================================================================
cd $TARGET_DIR

# ======================================================================
# Menu di selezione per l'utente
# Mostra le opzioni disponibili per il download.
# ======================================================================
echo "========================================================="
echo "MENU DI SELEZIONE ISO"
echo "========================================================="
echo "Quale file ISO vorresti scaricare?"
echo "1) Ubuntu Desktop 22.04.4 LTS (Jammy Jellyfish)"
echo "2) Ubuntu Server 22.04.4 LTS (Jammy Jellyfish)"
echo "3) Ubuntu Desktop 23.10 (Mantic Minotaur)"
echo "4) Ubuntu Server 23.10 (Mantic Minotaur)"
echo "5) Kali Linux 2024.4 Purple Edition"
echo "========================================================="
read -p "Inserisci la tua scelta [1-5]: " CHOICE

# ======================================================================
# Seleziona l'URL e il nome del file in base alla scelta dell'utente
# Imposta le variabili URL e FILENAME in base alla scelta effettuata.
# ======================================================================
case $CHOICE in
   1)
       URL="https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-desktop-amd64.iso"
       FILENAME="ubuntu-22.04.4-desktop-amd64.iso"
       ;;
   2)
       URL="https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso"
       FILENAME="ubuntu-22.04.4-live-server-amd64.iso"
       ;;
   3)
       URL="https://releases.ubuntu.com/23.10/ubuntu-23.10-desktop-amd64.iso"
       FILENAME="ubuntu-23.10-desktop-amd64.iso"
       ;;
   4)
       URL="https://releases.ubuntu.com/23.10/ubuntu-23.10-live-server-amd64.iso"
       FILENAME="ubuntu-23.10-live-server-amd64.iso"
       ;;
   5)
       URL="https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-installer-purple-amd64.iso"
       FILENAME="kali-linux-2024.4-installer-purple-amd64.iso"
       ;;
   *)
       echo "========================================================="
       echo "ERRORE: Scelta non valida. Uscita."
       echo "========================================================="
       exit 1
       ;;
esac

# ======================================================================
# Download del file ISO
# Utilizza wget per scaricare il file. L'opzione -c consente di
# riprendere un download interrotto.
# ======================================================================
echo "========================================================="
echo "INFO: Download di $FILENAME in corso..."
echo "INFO: Questo potrebbe richiedere del tempo in base alla tua connessione internet."
echo "========================================================="
wget -c $URL -O $FILENAME

# ======================================================================
# Verifica del download
# Controlla se il download è stato completato con successo.
# ======================================================================
if [ $? -eq 0 ]; then
   echo "========================================================="
   echo "SUCCESSO: Download completato!"
   echo "File ISO: $TARGET_DIR/$FILENAME"
   echo "Dimensione file: $(du -h $FILENAME | cut -f1)"
   echo "L'ISO è ora disponibile nell'interfaccia di Proxmox."
   echo "========================================================="
else
   echo "========================================================="
   echo "ERRORE: Download fallito!"
   echo "========================================================="
   exit 1
fi

# ======================================================================
# Impostazione dei permessi corretti
# Imposta i permessi del file  644 (lettura per tutti, scrittura solo
# per il proprietario) per garantire che Proxmox possa leggere il file.
# ======================================================================
chmod 644 $FILENAME
echo "========================================================="
echo "INFO: Permessi impostati a 644 per il file ISO."
echo "========================================================="
echo "Nota: Lo storage 'local' è già configurato automaticamente in Proxmox."
# ======================================================================
# Messaggio di completamento
# Informa l'utente che il processo è terminato e il file è pronto
# per essere utilizzato.
# ======================================================================
echo "========================================================="
echo "COMPLETATO: Tutto fatto! Ora puoi utilizzare questo ISO"
echo "per creare nuove VM tramite Proxmox."
echo "========================================================="