#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    scheme.sh                                          :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.fr          #
#                                                                                #
# ****************************************************************************** #

# File per sviluppatori - Crea solo la struttura iniziale
# Nota: Questo file non fa parte del software operativo

echo -e "\033[1;36mCreazione struttura progetto...\033[0m"

# 1. Crea directory principali
mkdir -p wpinstaller/{config,scripts,templates,logs}

# 2. Crea file di configurazione vuoti
touch wpinstaller/config/{wp_installer.cfg,env.cfg}

# 3. Crea template vuoti
touch wpinstaller/templates/{nginx-local.conf,nginx-prod.conf}

# 4. Crea script principali vuoti
touch wpinstaller/scripts/{0_launcher.sh,1_system_setup.sh,2_mysql_setup.sh,3_wordpress_setup.sh,4_ssl_setup.sh,5_final_config.sh}

# 5. Imposta permessi base
chmod 755 wpinstaller/scripts/*.sh

echo -e "\033[1;32mStruttura creata in: wpinstaller/\033[0m"
echo -e "\033[1;33mInserire manualmente il contenuto nei file creati prima dell'uso\033[0m"