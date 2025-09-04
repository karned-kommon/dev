#!/bin/bash

# Script de test pour Vault
source "$(dirname "$0")/vault.env"

echo "🔍 Test de la configuration Vault"
echo "=================================="

# Test 1: Vérifier l'état de Vault
echo "1. État de Vault:"
HEALTH=$(curl -s $VAULT_ADDR/v1/sys/health)
SEALED=$(echo "$HEALTH" | jq -r '.sealed')
INITIALIZED=$(echo "$HEALTH" | jq -r '.initialized')

if [ "$SEALED" = "false" ] && [ "$INITIALIZED" = "true" ]; then
    echo "   ✅ Vault opérationnel (initialisé et déverrouillé)"
else
    echo "   ❌ Vault non opérationnel (scellé: $SEALED, initialisé: $INITIALIZED)"
    exit 1
fi

# Test 2: Vérifier l'authentification
echo "2. Test d'authentification:"
AUTH_TEST=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/auth/token/lookup-self)
TOKEN_VALID=$(echo "$AUTH_TEST" | jq -r '.data.id' 2>/dev/null)

if [ "$TOKEN_VALID" != "null" ] && [ -n "$TOKEN_VALID" ]; then
    echo "   ✅ Token valide"
else
    echo "   ❌ Token invalide"
    exit 1
fi

# Test 3: Créer et lire un secret de test
echo "3. Test de création/lecture de secret:"
TEST_SECRET='{"data": {"test_key": "test_value", "timestamp": "'$(date)'"}}' 

# Créer le secret
CREATE_RESULT=$(curl -s -X POST \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TEST_SECRET" \
    $VAULT_ADDR/v1/secret/data/test-script)

# Lire le secret
READ_RESULT=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
    $VAULT_ADDR/v1/secret/data/test-script)

TEST_VALUE=$(echo "$READ_RESULT" | jq -r '.data.data.test_key' 2>/dev/null)

if [ "$TEST_VALUE" = "test_value" ]; then
    echo "   ✅ Création et lecture de secret réussies"
else
    echo "   ❌ Échec de création/lecture de secret"
    exit 1
fi

# Test 4: Vérifier les secrets préconfigurés
echo "4. Vérification des secrets préconfigurés:"
SECRET1=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
    $VAULT_ADDR/v1/secret/data/entities/c1d2e3f4-g5h6-i7j8-k9l0-m1n2o3p4qf3a/licenses/a1b2c3d4-e5f6-7890-1234-567890abcdef/database)

SECRET1_URI=$(echo "$SECRET1" | jq -r '.data.data.uri' 2>/dev/null)

if echo "$SECRET1_URI" | grep -q "mongodb://karned-mongodb:27017/karned"; then
    echo "   ✅ Secret MongoDB préconfigué trouvé"
else
    echo "   ⚠️  Secret MongoDB préconfigué non trouvé (normal si pas encore initialisé)"
fi

# Test 5: Auto-unseal service
echo "5. Vérification du service auto-unseal:"
if docker ps | grep -q "karned-vault-unseal"; then
    echo "   ✅ Service auto-unseal en cours d'exécution"
else
    echo "   ❌ Service auto-unseal non trouvé"
fi

echo ""
echo "🎉 Tests terminés avec succès !"
echo ""
echo "📝 Informations utiles:"
echo "   Interface Web: $VAULT_ADDR/ui"
echo "   Token: $VAULT_TOKEN"
echo "   Documentation: docs/VAULT.md"
echo ""
echo "🚀 Commandes utiles:"
echo "   source vault.env               # Charger les variables"
echo "   ./scripts/vault-manual-unseal.sh  # Déverrouiller manuellement"
echo "   docker logs karned-vault-unseal   # Logs auto-unseal"
