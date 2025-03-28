#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    scheme.sh                                          :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: thenizix <thenizix@protonmail.com>         +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2024/03/27 12:00:00 by thenizix          #+#    #+#                #
#    Updated: 2024/03/27 12:00:00 by thenizix         ###   ########.it          #
#                                                                                #
# ****************************************************************************** #

# File per sviluppatori - Crea solo la struttura iniziale
# Non fa parte del software operativo

echo -e "\033[1;36mCreazione struttura progetto...\033[0m"

# Crea directory principali
mkdir -p wpinstaller/{config,scripts,templates,logs}

# Crea file di configurazione vuoti
touch wpinstaller/config/{wp_installer.cfg,env.cfg}

# Crea template base
touch wpinstaller/templates/{nginx-local.conf,nginx-prod.conf}

# Crea script principali
touch wpinstaller/scripts/{0_launcher.sh,1_system_setup.sh,2_mysql_setup.sh,3_wordpress_setup.sh,4_ssl_setup.sh,5_final_config.sh}

echo -e "\033[1;32mStruttura creata in: wpinstaller/\033[0m"
echo -e "Modifica i file di configurazione prima di eseguire lo script principale"