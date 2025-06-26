#!/bin/bash

# Exécuter le script de configuration du réseau
echo "Configuration du réseau..."
./init/network.sh

# Démarrer les services avec docker-compose
echo "Démarrage des services..."
docker-compose up -d

# Les services vont démarrer en arrière-plan
echo "Les services démarrent en arrière-plan..."
# Pas besoin d'attendre un temps fixe, les scripts d'initialisation ont leur propre mécanisme de retry

# Exécuter le script d'initialisation de Redis
echo "Initialisation de Redis..."
./init/redis.sh

# Exécuter le script d'initialisation de Vault
echo "Initialisation de Vault..."
./init/vault.sh

# Exécuter le script d'initialisation de Keycloak
echo "Initialisation de Keycloak..."
./init/keycloak.sh

# Exécuter le script d'initialisation des licences
echo "Initialisation des licences..."
./init/license.sh

# Exécuter le script d'initialisation des recettes
echo "Initialisation des recettes..."
./init/recipe.sh

echo "Initialisation terminée!"
