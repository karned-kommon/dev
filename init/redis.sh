#!/bin/bash
set -e

# Configuration
REDIS_HOST="karned-redis"
REDIS_PORT="6379"
VAULT_TOKEN="root"

echo "Initialisation de Redis..."

# Attendre que Redis soit accessible
echo "Vérification de la connexion à Redis..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} ping > /dev/null 2>&1; then
    echo "✔ Connexion à Redis établie"
    break
  else
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
      echo "Erreur: Impossible de se connecter à Redis après $MAX_RETRIES tentatives"
      exit 1
    fi
    echo "Tentative $RETRY_COUNT/$MAX_RETRIES: Connexion à Redis échouée, nouvelle tentative dans 2 secondes..."
    sleep 2
  fi
done

# Ajouter la clé VAULT_TOKEN dans Redis
echo "Ajout de la clé VAULT_TOKEN dans Redis..."
if redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} SET VAULT_TOKEN ${VAULT_TOKEN}; then
  echo "✔ Clé VAULT_TOKEN ajoutée avec succès dans Redis"
else
  echo "Erreur: Impossible d'ajouter la clé VAULT_TOKEN dans Redis"
  exit 1
fi

# Vérifier que la clé a été ajoutée correctement
echo "Vérification de la clé VAULT_TOKEN..."
REDIS_VALUE=$(redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} GET VAULT_TOKEN)
if [ "$REDIS_VALUE" = "${VAULT_TOKEN}" ]; then
  echo "✔ Vérification réussie: VAULT_TOKEN = ${REDIS_VALUE}"
else
  echo "Erreur: La valeur de VAULT_TOKEN dans Redis ne correspond pas à la valeur attendue"
  exit 1
fi

echo "✔ Initialisation de Redis terminée"
