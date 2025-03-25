# 🚀 WordPress Nginx Auto-Installer (WSL Optimized)

> **Automazione completa per installazioni WordPress su WSL/Windows 11**  
> _Configurazione ottimizzata per VM pulite e sviluppo locale_

[![Licenza GPLv3](https://img.shields.io/badge/Licenza-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.html)

## 📌 Funzionalità Principali
- **Installazione automatica** di WordPress + Nginx + PHP + MariaDB
- **Configurazione SSL** integrata (self-signed o Let's Encrypt)
- **Ottimizzato per WSL2** e Windows 11
- **Pulizia automatica** delle installazioni precedenti

## 🛠️ Prerequisiti
- Windows 10/11 con WSL2 attivo
- Distro Ubuntu (consigliata 22.04 LTS)
- Accesso amministrativo (sudo)

## ⚡ Installazione Rapida
```bash
# 1. Clona il repository
git clone https://github.com/tuorepo/wordpress-nginx-installer.git
cd wordpress-nginx-installer

# 2. Modifica la configurazione (opzionale)
nano wp_installer.cfg

# 3. Avvia l'installazione
sudo ./launcher.sh
🌐 Configurazione Dominio
Modifica DOMAIN nel file di configurazione:

```bash 
DOMAIN="miosito.test"  # Sostituisci con il tuo dominio
ADMIN_EMAIL="admin@miosito.test"

🔍 Test dell'Installazione
bash
Copy
# Verifica servizi attivi
systemctl status nginx mariadb php8.3-fpm

# Test connessione WordPress
curl -I http://localhost

📚 Risorse Utili
(Documentazione WordPress)[https://wordpress.org/support/]

(Configurazione Nginx)[https://nginx.org/en/docs/]

(Guida Ufficiale WSL)[https://learn.microsoft.com/it-it/windows/wsl/]

📜 Licenza
Questo progetto è rilasciato sotto licenza GPLv3.
Riusa il codice citando l'autore:
TheNizix <student@nowhere>  
👋 Saluti e Baci 🚀
Happy coding! 💻❤️