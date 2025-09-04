#!/bin/bash

VAULT_ADDR="http://karned-vault:8200"
KEYS_FILE="/shared/vault-keys.json"
CHECK_INTERVAL=${CHECK_INTERVAL:-10}

echo "🔐 Service d'auto-unseal Vault démarré"
echo "Adresse Vault: $VAULT_ADDR"
echo "Intervalle de vérification: ${CHECK_INTERVAL}s"

while true; do
    # Vérifier si Vault est accessible (accepter aussi les codes d'erreur quand Vault est scellé)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "429" ] || [ "$HTTP_CODE" = "503" ] || [ "$HTTP_CODE" = "501" ]; then
        # Vérifier si Vault est scellé
        HEALTH_RESPONSE=$(curl -s "$VAULT_ADDR/v1/sys/health")
        SEALED=$(echo "$HEALTH_RESPONSE" | jq -r '.sealed // false')
        
        if [ "$SEALED" = "true" ]; then
            echo "🔒 Vault détecté scellé, tentative de déverrouillage..."
            
            if [ -f "$KEYS_FILE" ]; then
                UNSEAL_KEY=$(jq -r '.keys_base64[0]' "$KEYS_FILE")
                
                if [ "$UNSEAL_KEY" != "null" ] && [ -n "$UNSEAL_KEY" ]; then
                    RESPONSE=$(curl -s -X POST \
                        -H "Content-Type: application/json" \
                        -d "{\"key\": \"$UNSEAL_KEY\"}" \
                        "$VAULT_ADDR/v1/sys/unseal")
                    
                    NEW_SEALED=$(echo "$RESPONSE" | jq -r '.sealed // true')
                    if [ "$NEW_SEALED" = "false" ]; then
                        echo "✅ Vault déverrouillé automatiquement !"
                    else
                        echo "❌ Échec du déverrouillage automatique"
                        echo "Response: $RESPONSE"
                    fi
                else
                    echo "❌ Clé de déverrouillage invalide"
                fi
            else
                echo "❌ Fichier de clés non trouvé: $KEYS_FILE"
            fi
        else
            echo "✅ Vault opérationnel ($(date))"
        fi
    else
        echo "⏳ Vault non accessible (HTTP $HTTP_CODE), nouvelle tentative dans ${CHECK_INTERVAL}s..."
    fi
    
    sleep "$CHECK_INTERVAL"
done
