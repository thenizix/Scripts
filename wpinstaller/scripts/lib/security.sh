#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    security.sh                                        :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/29 08:00:00 by thenizix          #+#    #+#                #
#    Updated: 2025/03/29 08:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# Libreria per la gestione della sicurezza e delle credenziali
# Questo file contiene funzioni per la generazione sicura di password,
# la gestione delle credenziali e altre operazioni relative alla sicurezza

# ============================================================================== #
# SEZIONE: Generazione password sicure
# ============================================================================== #

# Funzione: Genera una password sicura
# Crea una password casuale con caratteri misti per maggiore sicurezza
# Parametri:
#   $1 - Lunghezza della password (default: 16)
#   $2 - File di log (opzionale)
generate_secure_password() {
    local length="${1:-16}"
    local log_file="$2"
    
    if [[ -n "${log_file}" ]]; then
        log "INFO" "Generazione password sicura (${length} caratteri)..." "${log_file}"
    fi
    
    # Metodo 1: Usa /dev/urandom (più sicuro)
    if [[ -r "/dev/urandom" ]]; then
        # Genera password con caratteri alfanumerici e simboli
        # tr -dc elimina tutti i caratteri non specificati
        # head -c prende solo i primi N caratteri
        local password=$(< /dev/urandom tr -dc 'a-zA-Z0-9!@#$%^&*()_+?><~' | head -c "${length}")
        
        # Verifica che la password sia stata generata correttamente
        if [[ ${#password} -eq ${length} ]]; then
            echo "${password}"
            return 0
        fi
    fi
    
    # Metodo 2: Usa OpenSSL (alternativa)
    if command -v openssl &> /dev/null; then
        local password=$(openssl rand -base64 $((length * 2)) | tr -dc 'a-zA-Z0-9!@#$%^&*()_+?><~' | head -c "${length}")
        
        if [[ ${#password} -eq ${length} ]]; then
            echo "${password}"
            return 0
        fi
    fi
    
    # Metodo 3: Fallback con date e md5sum (meno sicuro, ma sempre disponibile)
    local password=$(date +%s | md5sum | head -c "${length}")
    
    echo "${password}"
    return 0
}

# ============================================================================== #
# SEZIONE: Gestione directory credenziali
# ============================================================================== #

# Funzione: Crea una directory sicura per le credenziali
# Crea una directory con permessi restrittivi per salvare le credenziali
# Parametri:
#   $1 - Percorso della directory
#   $2 - File di log (opzionale)
create_secure_credentials_dir() {
    local creds_dir="$1"
    local log_file="$2"
    
    if [[ -n "${log_file}" ]]; then
        log "INFO" "Creazione directory sicura per credenziali: ${creds_dir}" "${log_file}"
    fi
    
    # Crea la directory se non esiste
    if [[ ! -d "${creds_dir}" ]]; then
        # Crea la directory con tutti i parent necessari
        mkdir -p "${creds_dir}"
    fi
    
    # Imposta permessi restrittivi (solo root può accedere)
    # 700 = rwx------ (solo il proprietario ha accesso completo)
    chmod 700 "${creds_dir}"
    
    # Verifica che la directory sia stata creata correttamente
    if [[ ! -d "${creds_dir}" ]]; then
        if [[ -n "${log_file}" ]]; then
            log "ERROR" "Impossibile creare directory per credenziali: ${creds_dir}" "${log_file}"
        fi
        return 1
    fi
    
    if [[ -n "${log_file}" ]]; then
        log "SUCCESS" "Directory sicura creata: ${creds_dir}" "${log_file}"
    fi
    return 0
}

# ============================================================================== #
# SEZIONE: Salvataggio e caricamento credenziali
# ============================================================================== #

# Funzione: Salva credenziali in un file
# Salva le credenziali in un file con formato VARIABILE='valore'
# Parametri:
#   $1 - Percorso del file
#   $2 - File di log (opzionale)
#   $@ - Coppie VARIABILE=valore da salvare
save_credentials() {
    local creds_file="$1"
    local log_file="$2"
    shift 2
    local creds=("$@")
    
    if [[ -n "${log_file}" ]]; then
        log "INFO" "Salvataggio credenziali in ${creds_file}..." "${log_file}"
    fi
    
    # Crea la directory se non esiste
    local creds_dir=$(dirname "${creds_file}")
    create_secure_credentials_dir "${creds_dir}" "${log_file}"
    
    # Crea il file con header
    cat > "${creds_file}" <<EOF
# Credenziali generate automaticamente
# $(date "+%Y-%m-%d %H:%M:%S")
# NON MODIFICARE MANUALMENTE!
EOF
    
    # Aggiungi ogni coppia VARIABILE=valore
    for cred in "${creds[@]}"; do
        # Estrai nome e valore
        local name=$(echo "${cred}" | cut -d= -f1)
        local value=$(echo "${cred}" | cut -d= -f2-)
        
        # Salva nel formato VARIABILE='valore'
        echo "${name}='${value}'" >> "${creds_file}"
    done
    
    # Imposta permessi restrittivi
    # 600 = rw------- (solo il proprietario può leggere/scrivere)
    chmod 600 "${creds_file}"
    
    if [[ -n "${log_file}" ]]; then
        log "SUCCESS" "Credenziali salvate in modo sicuro: ${creds_file}" "${log_file}"
    fi
    return 0
}

# Funzione: Carica credenziali da un file
# Carica le credenziali da un file nel formato VARIABILE='valore'
# Parametri:
#   $1 - Percorso del file
#   $2 - File di log (opzionale)
load_credentials() {
    local creds_file="$1"
    local log_file="$2"
    
    if [[ -n "${log_file}" ]]; then
        log "INFO" "Caricamento credenziali da ${creds_file}..." "${log_file}"
    fi
    
    # Verifica che il file esista
    if [[ ! -f "${creds_file}" ]]; then
        if [[ -n "${log_file}" ]]; then
            log "ERROR" "File credenziali non trovato: ${creds_file}" "${log_file}"
        fi
        return 1
    fi
    
    # Carica il file
    source "${creds_file}"
    
    if [[ -n "${log_file}" ]]; then
        log "SUCCESS" "Credenziali caricate da: ${creds_file}" "${log_file}"
    fi
    return 0
}

# ============================================================================== #
# SEZIONE: Generazione salt WordPress
# ============================================================================== #

# Funzione: Genera salt per WordPress
# Genera le chiavi di sicurezza per wp-config.php
# Parametri:
#   $1 - File di log (opzionale)
generate_wordpress_salts() {
    local log_file="$1"
    
    if [[ -n "${log_file}" ]]; then
        log "INFO" "Generazione salt per WordPress..." "${log_file}"
    fi
    
    # Definizione delle chiavi di sicurezza da generare
    local salt_keys=(
        "AUTH_KEY"
        "SECURE_AUTH_KEY"
        "LOGGED_IN_KEY"
        "NONCE_KEY"
        "AUTH_SALT"
        "SECURE_AUTH_SALT"
        "LOGGED_IN_SALT"
        "NONCE_SALT"
    )
    
    # Genera il codice PHP per i salt
    local salts=""
    for key in "${salt_keys[@]}"; do
        # Genera una stringa casuale di 64 caratteri per ogni chiave
        local salt=$(generate_secure_password 64)
        salts+="define('${key}', '${salt}');\n"
    done
    
    echo -e "${salts}"
    return 0
}

# ============================================================================== #
# SEZIONE: Hardening sicurezza
# ============================================================================== #

# Funzione: Applica misure di sicurezza di base
# Imposta permessi corretti e altre misure di sicurezza
# Parametri:
#   $1 - Directory WordPress
#   $2 - Utente proprietario
#   $3 - Gruppo proprietario
#   $4 - File di log (opzionale)
apply_security_hardening() {
    local wp_dir="$1"
    local wp_user="$2"
    local wp_group="$3"
    local log_file="$4"
    
    if [[ -n "${log_file}" ]]; then
        log "STEP" "Applicazione misure di sicurezza" "${log_file}"
    fi
    
    # Verifica che la directory esista
    if [[ ! -d "${wp_dir}" ]]; then
        if [[ -n "${log_file}" ]]; then
            log "ERROR" "Directory WordPress non trovata: ${wp_dir}" "${log_file}"
        fi
        return 1
    fi
    
    # Imposta proprietario e gruppo
    if [[ -n "${log_file}" ]]; then
        log "INFO" "Impostazione proprietario e gruppo: ${wp_user}:${wp_group}" "${log_file}"
    fi
    chown -R "${wp_user}":"${wp_group}" "${wp_dir}"
    
    # Imposta permessi directory
    if [[ -n "${log_file}" ]]; then
        log "INFO" "Impostazione permessi directory: ${DIR_PERMS:-750}" "${log_file}"
    fi
    find "${wp_dir}" -type d -exec chmod "${DIR_PERMS:-750}" {} \;
    
    # Imposta permessi file
    if [[ -n "${log_file}" ]]; then
        log "INFO" "Impostazione permessi file: ${FILE_PERMS:-640}" "${log_file}"
    fi
    find "${wp_dir}" -type f -exec chmod "${FILE_PERMS:-640}" {} \;
    
    # Permessi speciali per wp-config.php (più restrittivi)
    if [[ -f "${wp_dir}/wp-config.php" ]]; then
        if [[ -n "${log_file}" ]]; then
            log "INFO" "Impostazione permessi speciali per wp-config.php: 600" "${log_file}"
        fi
        chmod 600 "${wp_dir}/wp-config.php"
    fi
    
    # Permessi di esecuzione per directory wp-content/uploads
    if [[ -d "${wp_dir}/wp-content/uploads" ]]; then
        if [[ -n "${log_file}" ]]; then
            log "INFO" "Impostazione permessi speciali per wp-content/uploads" "${log_file}"
        fi
        chmod 750 "${wp_dir}/wp-content/uploads"
    fi
    
    if [[ -n "${log_file}" ]]; then
        log "SUCCESS" "Misure di sicurezza applicate con successo" "${log_file}"
    fi
    return 0
}

# ============================================================================== #
# SEZIONE: Controllo esecuzione diretta
# ============================================================================== #

# Questo blocco impedisce l'esecuzione diretta di questo script
# Il file è progettato per essere importato da altri script, non eseguito direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Questo script è una libreria e non dovrebbe essere eseguito direttamente."
    echo "Deve essere importato da altri script tramite 'source'."
    exit 1
fi
