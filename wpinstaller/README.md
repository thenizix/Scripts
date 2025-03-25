# WP-NGINX Auto-Installer 🚀

> One-command WordPress deployment on Nginx-PHP-MySQL stack with automatic hardening

## 📦 Quick Start

```bash
git clone --depth=1 https://github.com/TheNizix/Scripts.git
cd Scripts/wpinstaller
sudo ./launcher.sh
🔧 Configuration Edit wp_installer.cfg before running:

DOMAIN="yourdomain.com"       # Or "localhost" for development ADMIN_EMAIL="admin@email.com" # For SSL certificates MYSQL_ROOT_PASS="StrongPass!" # Change default credentials! 🌟 Features Automatic Stack Deployment: Nginx (optimized workers + security headers) PHP-FPM (Opcache + 256M memory) MariaDB (utf8mb4 + hardening) SSL Options: Auto-configured Self-Signed (dev) Let's Encrypt (production) WordPress: Secure wp-config.php Disabled file editor Correct permissions 🛠️ Troubleshooting
Check services
systemctl status nginx mariadb php${PHP_VERSION}-fpm
View installation log
tail -f wp_install.log
Test SSL (Let's Encrypt)
certbot certificates 📄 License: GPLv3 - TheNizix

