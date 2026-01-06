#!/bin/bash
set -e

# Création des répertoires de logs si nécessaire
mkdir -p /var/log

# Vérification de la configuration
echo "Vérification de la configuration syslog-ng..."
syslog-ng --syntax-only --cfgfile=/etc/syslog-ng/syslog-ng.conf

# Démarrage de syslog-ng en mode foreground
echo "Démarrage de syslog-ng..."
exec syslog-ng --foreground --cfgfile=/etc/syslog-ng/syslog-ng.conf --verbose
#