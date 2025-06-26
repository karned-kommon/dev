#!/bin/bash
set -e

KEYCLOAK_URL=http://localhost:5990
ADMIN_USERNAME=karned-admin
ADMIN_PASSWORD=topsecret
REALM=karned
CLIENT_ID=karned-client
CLIENT_SECRET=secret

echo "Attente du démarrage de Keycloak..."
until curl -s "$KEYCLOAK_URL/health/ready" > /dev/null; do
  sleep 2
done


echo "Connexion avec l'admin permanent..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USERNAME" \
  -d "password=$ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")
TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r 'if has("access_token") then .access_token else empty end')

if [ -z "$TOKEN" ]; then
  echo "Échec de connexion avec l'admin permanent: $(echo "$TOKEN_RESPONSE" | jq -r 'if has("error_description") then .error_description else "Erreur inconnue" end')"
  exit 1
fi


echo "Création de l'utilisateur user1..."
USER_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user1",
    "enabled": true,
    "email": "user1@example.com",
    "emailVerified": true,
    "requiredActions": [],
    "credentials": [{"type":"password", "value":"password", "temporary":false}],
    "firstName": "User",
    "lastName": "One"
}')

if [ -n "$USER_RESPONSE" ]; then
  echo "Réponse de création de l'utilisateur: $USER_RESPONSE"
  if echo "$USER_RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "Erreur lors de la création de l'utilisateur: $(echo "$USER_RESPONSE" | jq -r '.error_description // .errorMessage // .error')"
    # Continue anyway, the user might already exist
  fi
fi

echo "✔ Initialisation terminée"
