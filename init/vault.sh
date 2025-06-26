#!/bin/bash
set -e

# Configuration
VAULT_ADDR="http://localhost:5991"
VAULT_TOKEN="root"
SECRET_VALUE="mongodb://localhost:5971/karned"

echo "Initialisation du Vault..."

# Attendre que Vault soit accessible
echo "Vérification de la connexion à Vault..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  VAULT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${VAULT_ADDR}/v1/sys/health)

  if [ "$VAULT_STATUS" = "200" ] || [ "$VAULT_STATUS" = "429" ]; then
    echo "✔ Connexion à Vault établie (status: ${VAULT_STATUS})"
    break
  else
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
      echo "Erreur: Impossible de se connecter à Vault après $MAX_RETRIES tentatives (dernier status: ${VAULT_STATUS})"
      exit 1
    fi
    echo "Tentative $RETRY_COUNT/$MAX_RETRIES: Connexion à Vault échouée (status: ${VAULT_STATUS}), nouvelle tentative dans 2 secondes..."
    sleep 2
  fi
done

# Créer les secrets dans Vault pour les deux licences
# Premier secret
SECRET_PATH1="entities/c1d2e3f4-g5h6-i7j8-k9l0-m1n2o3p4qf3a/licenses/a1b2c3d4-e5f6-7890-1234-567890abcdef/database"
echo "Création du premier secret dans Vault..."
curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "{\"data\": {\"value\": \"${SECRET_VALUE}\"}}" \
  ${VAULT_ADDR}/v1/secret/data/${SECRET_PATH1}

# Vérifier que le premier secret a été créé
echo "Vérification de la création du premier secret..."
SECRET_CHECK1=$(curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -X GET \
  ${VAULT_ADDR}/v1/secret/data/${SECRET_PATH1})

if echo "$SECRET_CHECK1" | grep -q "\"value\":\"${SECRET_VALUE}\""; then
  echo "✔ Premier secret créé avec succès dans Vault: ${SECRET_PATH1}"
else
  echo "Erreur: Le premier secret n'a pas été créé correctement"
  exit 1
fi

# Deuxième secret
SECRET_PATH2="entities/c1d2e3f4-g5h6-i7j8-k9l0-m1n2o3p4j5rf/licenses/b1b2c3d4-e5f6-7890-1234-567890ghijk/database"
echo "Création du deuxième secret dans Vault..."
curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "{\"data\": {\"value\": \"${SECRET_VALUE}\"}}" \
  ${VAULT_ADDR}/v1/secret/data/${SECRET_PATH2}

# Vérifier que le deuxième secret a été créé
echo "Vérification de la création du deuxième secret..."
SECRET_CHECK2=$(curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -X GET \
  ${VAULT_ADDR}/v1/secret/data/${SECRET_PATH2})

if echo "$SECRET_CHECK2" | grep -q "\"value\":\"${SECRET_VALUE}\""; then
  echo "✔ Deuxième secret créé avec succès dans Vault: ${SECRET_PATH2}"
else
  echo "Erreur: Le deuxième secret n'a pas été créé correctement"
  exit 1
fi

echo "✔ Initialisation du Vault terminée"
