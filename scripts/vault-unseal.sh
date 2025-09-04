#!/bin/bash

VAULT_ADDR="http://localhost:8200"
KEYS_FILE="/vault/data/vault-keys.json"

# Fonction pour vérifier si Vault est accessible
wait_for_vault() {
    echo "Attente de Vault..."
    for i in {1..30}; do
        if curl -sf "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
            echo "✓ Vault est accessible"
            return 0
        fi
        echo "Tentative $i/30..."
        sleep 2
    done
    echo "✗ Impossible d'accéder à Vault"
    return 1
}

# Fonction pour vérifier si Vault est scellé
is_sealed() {
    local status=$(curl -s "$VAULT_ADDR/v1/sys/health" | jq -r '.sealed // false')
    [ "$status" = "true" ]
}

# Fonction pour déverrouiller Vault
unseal_vault() {
    if [ ! -f "$KEYS_FILE" ]; then
        echo "✗ Fichier de clés non trouvé: $KEYS_FILE"
        return 1
    fi
    
    local unseal_key=$(jq -r '.keys_base64[0]' "$KEYS_FILE")
    if [ "$unseal_key" = "null" ] || [ -z "$unseal_key" ]; then
        echo "✗ Clé de déverrouillage non trouvée dans $KEYS_FILE"
        return 1
    fi
    
    echo "Déverrouillage de Vault..."
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"$unseal_key\"}" \
        "$VAULT_ADDR/v1/sys/unseal")
    
    local sealed=$(echo "$response" | jq -r '.sealed // true')
    if [ "$sealed" = "false" ]; then
        echo "✓ Vault déverrouillé avec succès"
        return 0
    else
        echo "✗ Échec du déverrouillage"
        echo "$response"
        return 1
    fi
}

# Script principal
main() {
    if ! wait_for_vault; then
        exit 1
    fi
    
    if is_sealed; then
        echo "Vault est scellé, tentative de déverrouillage..."
        unseal_vault
    else
        echo "✓ Vault est déjà déverrouillé"
    fi
}

main "$@"
