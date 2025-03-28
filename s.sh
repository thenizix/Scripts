#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    scheme_rebuild.sh                                  :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

set -e

# Colori per output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directory principale
BASE_DIR="wpinstaller"

# Funzione per creare directory
create_dir() {
    mkdir -p "$1"
    echo -e "${GREEN}✓ Creata directory: $1${NC}"
}

# Funzione per creare file con template base
create_file() {
    touch "$1"
    echo -e "${GREEN}✓ Creato file: $1${NC}"
    
    # Aggiungi header standard se è uno script bash
    if [[ "$1" == *.sh ]]; then
        cat > "$1" << EOL
#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    $(basename "$1")                                   :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: $(date '+%Y/%m/%d %H:%M:%S') by thenizix          #+#    #+#                #
#    Updated: $(date '+%Y/%m/%d %H:%M:%S') by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

EOL
    fi
}

# Funzione principale
main() {
    echo -e "${YELLOW}🚀 Ricostruzione struttura wpinstaller${NC}"
    
    # Crea directory principali
    create_dir "${BASE_DIR}"
    create_dir "${BASE_DIR}/config"
    create_dir "${BASE_DIR}/scripts"
    create_dir "${BASE_DIR}/templates"
    create_dir "${BASE_DIR}/logs"
    
    # File di configurazione base
    create_file "${BASE_DIR}/config/wp_installer.cfg"
    create_file "${BASE_DIR}/config/env.cfg"
    
    # Template Nginx
    create_file "${BASE_DIR}/templates/nginx-local.conf"
    create_file "${BASE_DIR}/templates/nginx-prod.conf"
    
    # Script principali
    script_names=(
        "0_launcher.sh"
        "1_system_setup.sh"
        "2_mysql_setup.sh"
        "3_wordpress_setup.sh"
        "4_ssl_setup.sh"
        "5_final_config.sh"
    )
    
    for script in "${script_names[@]}"; do
        create_file "${BASE_DIR}/scripts/${script}"
    done
    
    echo -e "${GREEN}✅ Struttura ricostruita con successo!${NC}"
}

# Esegui lo script principale
main
