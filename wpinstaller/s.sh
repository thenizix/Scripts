#!/bin/bash
# SCRIPT DI AUTO-RIPARAZIONE PER WP INSTALLER

# -------------------------------
# CONFIGURAZIONE
# -------------------------------
BACKUP_DIR="./backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="./repair.log"
PHP_VERSION="8.3"  # Modificare se necessario

# -------------------------------
# FUNZIONI DI UTILITÀ
# -------------------------------
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

backup_file() {
    cp "$1" "$BACKUP_DIR"/
}

apply_patch() {
    file="$1"
    pattern="$2"
    replacement="$3"
    
    backup_file "$file"
    awk -v pat="$pattern" -v rep="$replacement" '{gsub(pat, rep)}1' "$file" > temp_file
    mv temp_file "$file"
}

# -------------------------------
# INIZIO RIPARAZIONI
# -------------------------------
mkdir -p "$BACKUP_DIR"
log "Inizio processo di riparazione..."

# 1. Correzione percorsi log
find ./scripts -type f -exec sed -i 's|LOG_DIR=.*|LOG_DIR="'$(pwd)'/logs"|g' {} \;
mkdir -p "$(pwd)/logs"
chmod 777 "$(pwd)/logs"

# 2. Aggiornamento gestione PHP-FPM
for file in ./scripts/*.sh; do
    apply_patch "$file" "php-fpm" "php${PHP_VERSION}-fpm"
    apply_patch "$file" "service php-fpm" "service php${PHP_VERSION}-fpm"
done

# 3. Aggiunta pulizia MariaDB
apply_patch "./scripts/2_mysql_setup.sh" \
    "# Aggiungere prima della configurazione" \
    "# Pulizia processi residui\nsudo killall -9 mariadbd 2>/dev/null\nsudo rm -rf /var/lib/mysql/*\nsudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql\nsudo chown -R mysql:mysql /var/lib/mysql\n"

# 4. Configurazione WSL
apply_patch "./config/wp_installer.cfg" \
    "# CONFIGURAZIONE PRINCIPALE" \
    "# Config WSL\nif grep -qi \"microsoft\" /proc/version; then\n    MYSQL_SOCKET=\"/run/mysqld/mysqld.sock\"\nelse\n    MYSQL_SOCKET=\"/var/run/mysqld/mysqld.sock\"\nfi\n\n# CONFIGURAZIONE PRINCIPALE"

# 5. Correzione template Nginx
apply_patch "./templates/nginx-prod.conf" \
    "fastcgi_pass unix:/run/php/php-fpm.sock" \
    "fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock"

# 6. Aggiunta pre-check
apply_patch "./scripts/0_launcher.sh" \
    "main_menu() {" \
    "check_dependencies() {\n    local missing=()\n    [ -d \"/var/lib/mysql\" ] || missing+=(\"mysql-dir\")\n    [ -f \"/etc/php/${PHP_VERSION}/fpm/php.ini\" ] || missing+=(\"php-fpm\")\n    \n    if [ \${#missing[@]} -gt 0 ]; then\n        echo -e \"\\033[0;31m[ERR] Componenti mancanti: \${missing[*]}\\033[0m\"\n        exit 1\n    fi\n}\n\nmain_menu() {\n    check_dependencies"

# -------------------------------
# FINE RIPARAZIONI
# -------------------------------
log "Riparazioni completate! Backup salvato in: $BACKUP_DIR"
log "Eseguire questi comandi prima di riavviare:"
echo -e "\n1. sudo chmod +x scripts/*.sh"
echo "2. sudo rm -rf /var/lib/mysql/*"
echo "3. sudo killall -9 mariadbd"
echo "4. sudo ./scripts/0_launcher.sh"x
