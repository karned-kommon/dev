#!/bin/bash

# Attendre que Keycloak soit prêt
echo "Attente du démarrage de Keycloak..."
while ! curl -s http://localhost:5990/health/ready; do
  sleep 5
done

# Obtenir un token d'accès admin
echo "Obtention du token admin..."
TOKEN=$(curl -s -X POST http://localhost:5990/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')


# Créer un client
echo "Création d'un client..."
curl -s -X POST http://localhost:5990/admin/realms/karned/clients \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"clientId":"karned-client", "enabled":true, "publicClient":true, "redirectUris":["*"], "webOrigins":["*"]}'


echo "Initialisation de Keycloak terminée!"
