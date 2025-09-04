#!/bin/bash

# Script simple pour déverrouiller Vault manuellement
VAULT_ADDR="http://localhost:5991"
KEYS_FILE="/Users/killian/Karned/Kommon/dev/.vault_data/vault-keys.json"

echo "🔐 Vérification de l'état de Vault..."

# Vérifier l'état de Vault
HEALTH=$(curl -s "$VAULT_ADDR/v1/sys/health")
SEALED=$(echo "$HEALTH" | jq -r '.sealed // false')
INITIALIZED=$(echo "$HEALTH" | jq -r '.initialized // false')

echo "Initialisé: $INITIALIZED"
echo "Scellé: $SEALED"

if [ "$SEALED" = "true" ]; then
    echo "🔒 Vault est scellé, déverrouillage..."
    
    if [ -f "$KEYS_FILE" ]; then
        UNSEAL_KEY=$(jq -r '.keys_base64[0]' "$KEYS_FILE")
        
        if [ "$UNSEAL_KEY" != "null" ] && [ -n "$UNSEAL_KEY" ]; then
            RESPONSE=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "{\"key\": \"$UNSEAL_KEY\"}" \
                "$VAULT_ADDR/v1/sys/unseal")
            
            NEW_SEALED=$(echo "$RESPONSE" | jq -r '.sealed // true')
            if [ "$NEW_SEALED" = "false" ]; then
                echo "✅ Vault déverrouillé avec succès !"
            else
                echo "❌ Échec du déverrouillage"
                echo "$RESPONSE" | jq .
            fi
        else
            echo "❌ Clé de déverrouillage introuvable"
        fi
    else
        echo "❌ Fichier de clés non trouvé: $KEYS_FILE"
    fi
else
    echo "✅ Vault est déjà déverrouillé"
fi

# Afficher le token root pour facilité
if [ -f "$KEYS_FILE" ]; then
    ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
    echo ""
    echo "🔑 Token root: $ROOT_TOKEN"
    echo "🌐 Interface Web: http://localhost:5991/ui"
fi
