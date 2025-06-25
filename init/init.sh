#!/bin/bash

# Exécuter le script de configuration du réseau
echo "Configuration du réseau..."
./init/network.sh

# Démarrer les services avec docker-compose
echo "Démarrage des services..."
docker-compose up -d

# Attendre quelques secondes pour que les services démarrent
echo "Attente du démarrage des services..."
sleep 10

# Exécuter le script d'initialisation de Keycloak
echo "Initialisation de Keycloak..."
./init/keycloak.sh

echo "Initialisation terminée!"
