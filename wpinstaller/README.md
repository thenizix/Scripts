# WP-Nginx Auto-Installer

> Strumento per deploy automatizzato di WordPress su stack Nginx-PHP-MySQL (ottimizzato per WSL2/Windows)

## 🚀 Installazione

```bash
# 1. Clona solo la directory wpinstaller
git clone --depth 1 --filter=blob:none --sparse https://github.com/TheNizix/Scripts.git && \
cd Scripts && git sparse-checkout set wpinstaller && \
chmod +x wpinstaller/ -R && cd wpinstaller
```

## ⚙️ Configurazione

Modificare prima dell'esecuzione:
```bash
nano wp_installer.cfg  # Modificare almeno:
DOMAIN="tuo.dominio"       # O "localhost" per sviluppo
ADMIN_EMAIL="admin@email"  # Per certificati SSL
MYSQL_ROOT_PASS="***"      # Cambiare password di default!
```

## 🏁 Esecuzione
```bash
sudo ./launcher.sh
```
- **Self-Signed SSL**: Per sviluppo locale
- **Let's Encrypt**: Per produzione (richiede dominio pubblico)

## 🔧 Stack Installato
| Componente  | Configurazione |
|-------------|----------------|
| Nginx       | Worker ottimizzati, Gzip, Headers sicurezza |
| PHP-FPM     | Pool dinamico, Memory 256M, Opcache |
| MariaDB     | Hardening automatico, UTF8mb4 |
| WordPress   | Ultima versione, permessi sicuri |

## 🔒 Hardening
- Generazione chiavi sicurezza uniche
- Disabilitazione editor temi/plugin
- Protezione file sensibili (.htaccess, wp-config)
- Cipher SSL moderni (TLS 1.2/1.3)

## ⚡ Ottimizzazioni
- **Nginx**: Keepalive 65s, Worker auto, Max body 64M
- **PHP**: Timeout 300s, Upload 64M, Opcache
- **DB**: Collation utf8mb4_unicode_ci

## 🛠️ Troubleshooting
```bash
# Verifica servizi
systemctl status nginx mariadb phpX.X-fpm

# Log installazione
tail -f wp_install.log

# Certificati SSL (Let's Encrypt)
certbot certificates
```

📄 **Licenza**: GPLv3 - [TheNizix](https://github.com/TheNizix)