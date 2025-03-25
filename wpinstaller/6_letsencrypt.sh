#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    6_letsencrypt.sh                                   :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

# ============================================================================== #
#                          CERTIFICATI LET'S ENCRYPT                             #
# ============================================================================== #
# Questo script:
# 1. Installa Certbot
# 2. Ottiene certificati SSL validi
# 3. Configura il rinnovo automatico
# ============================================================================== #

source $(dirname "$0")/wp_installer.cfg

# ============================================================================== #
#                          VERIFICA PREREQUISITI                                 #
# ============================================================================== #
if [ "$DOMAIN" = "localhost" ]; then
    echo -e "${RED}ERRORE: Impossibile usare Let's Encrypt con localhost${NC}"
    echo -e "Modificare il dominio in wp_installer.cfg"
    exit 1
fi

# Verifica porta 80 aperta
if ! nc -z localhost 80; then
    echo -e "${RED}ERRORE: Porta 80 non disponibile${NC}"
    echo -e "Necessaria per la verifica Let's Encrypt"
    exit 1
fi

# ============================================================================== #
#                          INSTALLAZIONE CERTBOT                                 #
# ============================================================================== #
echo -e "${YELLOW}[1/3] Installazione Certbot...${NC}"
apt update >/dev/null
apt install -y certbot python3-certbot-nginx >/dev/null
_check

# ============================================================================== #
#                          OTTENIMENTO CERTIFICATI                               #
# ============================================================================== #
echo -e "${YELLOW}[2/3] Ottenimento certificati...${NC}"
certbot --nginx --non-interactive --agree-tos -m ${ADMIN_EMAIL} -d ${DOMAIN} --redirect
_check

# ============================================================================== #
#                          RINNOVO AUTOMATICO                                    #
# ============================================================================== #
echo -e "${YELLOW}[3/3] Configurazione rinnovi...${NC}"
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
_check

# ============================================================================== #
#                          FINE SCRIPT                                           #
# ============================================================================== #
echo -e "${GREEN}\nCertificati Let's Encrypt configurati!${NC}"
echo -e "Scadenza certificati: ${YELLOW}$(certbot certificates | grep 'Expiry Date')${NC}"