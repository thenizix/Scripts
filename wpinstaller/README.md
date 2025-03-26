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
     certbot certificates 
     
📄 License: GPLv3 - TheNizix 

-----------------------------------------------
Note.  Some precise Errors from the Wordpress installer could be not a real error.
The correct wordpress installation would to be made from the wp php installer, so it switch to "manual install".

- Remember to secure the instance deleting any trace of installers.

-Maybe this software could have some silly redundancy or ingenuity, maybe i reinvented the wheel.. but is useful and instead to modify something, i tried to make it express from myself.
but...
I'm proud like a child of this, lost hours tryng to fixing sed , and i become a fan of awk..  
- Built in some hours using VSCode and Deepseek 3.1
- as a student i would share anyway the 42 logo, and way to learn and share, even if this is not a 42 project.
Pull it and make it better, let me know.



