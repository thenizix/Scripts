#!/bin/bash
# ****************************************************************************** #
#                                                                                #
#                                                         :::      ::::::::      #
#    4_ssl_setup.sh                                     :+:      :+:    :+:      #
#                                                     +:+ +:+         +:+        #
#    By: TheNizix                                   +#+  +:+       +#+           #
#                                                 +#+#+#+#+#+   +#+              #
#    Created: 2025/03/25 15:00:00 by TheNizix          #+#    #+#                #
#    Updated: 2025/03/25 15:00:00 by TheNizix         ###   ######## Firenze     #
#                                                                                #
# ****************************************************************************** #

# ****************************************************************************** #
#                                                                                #
#           CONFIGURAZIONE SSL SELF-SIGNED PER WORDPRESS - WSL/Win               #
#                                                                                #
# ****************************************************************************** #

source wp_installer.cfg
exec > >(tee -a wp_install.log) 2>&1

# Funzione per generare certificati SSL
generate_ssl() {
    echo -e "\033[1;33m🔐 Generazione certificati SSL...\033[0m"
    
    # Crea directory certificati
    mkdir -p /etc/nginx/ssl
    
    # Genera chiave privata
    openssl genrsa -out "/etc/nginx/ssl/${DOMAIN}.key" 2048
    
    # Genera CSR (Certificate Signing Request)
    openssl req -new -key "/etc/nginx/ssl/${DOMAIN}.key" \
        -out "/etc/nginx/ssl/${DOMAIN}.csr" \
        -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_LOCALITY}/O=${SSL_ORG}/OU=${SSL_OU}/CN=${DOMAIN}/emailAddress=${ADMIN_EMAIL}"
    
    # Genera certificato autofirmato
    openssl x509 -req -days ${SSL_DAYS} \
        -in "/etc/nginx/ssl/${DOMAIN}.csr" \
        -signkey "/etc/nginx/ssl/${DOMAIN}.key" \
        -out "/etc/nginx/ssl/${DOMAIN}.crt"
}

# Funzione per configurare Nginx con SSL
configure_nginx_ssl() {
    echo -e "\033[1;33m⚙️ Configurazione Nginx con SSL...\033[0m"
    
    # Backup configurazione esistente
    cp /etc/nginx/sites-available/wordpress /etc/nginx/sites-available/wordpress.bak
    
    # Configurazione SSL avanzata
    cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    root ${WP_DIR};

    ssl_certificate /etc/nginx/ssl/${DOMAIN}.crt;
    ssl_certificate_key /etc/nginx/ssl/${DOMAIN}.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ${SSL_CIPHERS};
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 1.1.1.1 valid=300s;
    resolver_timeout 5s;
    
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    # Test configurazione
    if ! nginx -t; then
        echo -e "\033[0;31m❌ Configurazione SSL non valida!\033[0m"
        # Ripristino backup
        mv /etc/nginx/sites-available/wordpress.bak /etc/nginx/sites-available/wordpress
        exit 1
    fi
    
    systemctl reload nginx
}

# Main execution
echo -e "\033[1;36m🚀 Configurazione SSL...\033[0m"
validate_config
generate_ssl
configure_nginx_ssl

echo -e "\033[0;32m✅ SSL configurato correttamente\033[0m"
echo -e "\033[1;33m🔑 Certificati generati in /etc/nginx/ssl/\033[0m"