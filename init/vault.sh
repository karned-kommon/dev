#!/bin/bash
set -e

# Configuration
VAULT_ADDR="http://karned-vault:8200"
SECRET_VALUE="mongodb://karned-mongodb:27017/karned"

echo "Initialisation du Vault..."

# Attendre que Vault soit accessible
echo "Vérification de la connexion à Vault..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  VAULT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${VAULT_ADDR}/v1/sys/health)

  if [ "$VAULT_STATUS" = "200" ] || [ "$VAULT_STATUS" = "429" ] || [ "$VAULT_STATUS" = "501" ]; then
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

# Vérifier si Vault est initialisé
echo "Vérification de l'état d'initialisation de Vault..."
INIT_STATUS=$(curl -s ${VAULT_ADDR}/v1/sys/init | jq -r '.initialized')

if [ "$INIT_STATUS" = "false" ]; then
  echo "Initialisation de Vault..."
  INIT_RESPONSE=$(curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"secret_shares": 1, "secret_threshold": 1}' \
    ${VAULT_ADDR}/v1/sys/init)
  
  # Sauvegarder les clés
  echo "$INIT_RESPONSE" > /app/flags/vault-keys.json
  
  # Extraire la clé de déverrouillage et le token root
  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r '.keys[0]')
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r '.root_token')
  
  echo "Déverrouillage de Vault..."
  curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"key\": \"$UNSEAL_KEY\"}" \
    ${VAULT_ADDR}/v1/sys/unseal
  
  echo "Vault initialisé et déverrouillé !"
  echo "Token root: $VAULT_TOKEN"
else
  echo "Vault déjà initialisé"
  
  # Vérifier si Vault est scellé
  SEALED_STATUS=$(curl -s ${VAULT_ADDR}/v1/sys/health | jq -r '.sealed // false')
  
  if [ "$SEALED_STATUS" = "true" ]; then
    if [ -f "/app/flags/vault-keys.json" ]; then
      echo "Déverrouillage de Vault avec les clés existantes..."
      UNSEAL_KEY=$(cat /app/flags/vault-keys.json | jq -r '.keys[0]')
      curl -s \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"$UNSEAL_KEY\"}" \
        ${VAULT_ADDR}/v1/sys/unseal
    else
      echo "Erreur: Vault est scellé mais aucune clé trouvée!"
      exit 1
    fi
  fi
  
  # Récupérer le token depuis les clés sauvegardées
  if [ -f "/app/flags/vault-keys.json" ]; then
    VAULT_TOKEN=$(cat /app/flags/vault-keys.json | jq -r '.root_token')
  else
    echo "Erreur: Impossible de trouver le token root!"
    exit 1
  fi
fi

# Activer le moteur de secrets KV v2 si pas encore fait
echo "Activation du moteur de secrets KV v2..."
curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"type": "kv", "options": {"version": "2"}}' \
  ${VAULT_ADDR}/v1/sys/mounts/secret || echo "Moteur de secrets déjà activé"

# Créer les secrets dans Vault pour les deux licences
# Premier secret
SECRET_PATH1="entities/c1d2e3f4-g5h6-i7j8-k9l0-m1n2o3p4qf3a/licenses/a1b2c3d4-e5f6-7890-1234-567890abcdef/database"
echo "Création du premier secret dans Vault..."
curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "{\"data\": {\"uri\": \"${SECRET_VALUE}\"}}" \
  ${VAULT_ADDR}/v1/secret/data/${SECRET_PATH1}

sleep 2

# Vérifier que le premier secret a été créé
echo "Vérification de la création du premier secret..."
SECRET_CHECK1=$(curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -X GET \
  ${VAULT_ADDR}/v1/secret/data/${SECRET_PATH1})

if echo "$SECRET_CHECK1" | grep -q "\"uri\""; then
  echo "✔ Premier secret créé avec succès dans Vault: ${SECRET_PATH1}"
else
  echo "Erreur: Le premier secret n'a pas été créé correctement"
fi

# Deuxième secret
SECRET_PATH2="entities/c1d2e3f4-g5h6-i7j8-k9l0-m1n2o3p4j5rf/licenses/b1b2c3d4-e5f6-7890-1234-567890ghijk/database"
echo "Création du deuxième secret dans Vault..."
curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "{\"data\": {\"uri\": \"${SECRET_VALUE}\"}}" \
  ${VAULT_ADDR}/v1/secret/data/${SECRET_PATH2}

sleep 2

# Vérifier que le deuxième secret a été créé
echo "Vérification de la création du deuxième secret..."
SECRET_CHECK2=$(curl -s \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -X GET \
  ${VAULT_ADDR}/v1/secret/data/${SECRET_PATH2})

if echo "$SECRET_CHECK2" | grep -q "\"uri\""; then
  echo "✔ Deuxième secret créé avec succès dans Vault: ${SECRET_PATH2}"
else
  echo "Erreur: Le deuxième secret n'a pas été créé correctement"
fi

echo "✔ Initialisation du Vault terminée"
echo ""
echo "=== INFORMATIONS VAULT ==="
echo "Interface Web: http://localhost:5991/ui"
echo "Token Root: ${VAULT_TOKEN}"
echo "Clés sauvegardées: /app/flags/vault-keys.json"
echo "Documentation: docs/VAULT.md"
echo "Variables d'env: source vault.env"
echo "=========================="
