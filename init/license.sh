#!/bin/bash
set -e

KEYCLOAK_URL=http://karned-keycloak:8080
ADMIN_USERNAME=karned-admin
ADMIN_PASSWORD=topsecret
REALM=karned
CLIENT_ID=karned
CLIENT_SECRET=secret
MONGODB_HOST=karned-mongodb
MONGODB_PORT=27017
MONGODB_DATABASE=karned
MONGODB_COLLECTION=license
LICENSE_FILE="/app/data/karned.license.json"

echo "Initialisation des licences..."

# Connexion à Keycloak pour obtenir un token
echo "Connexion à Keycloak..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USERNAME" \
  -d "password=$ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")
TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r 'if has("access_token") then .access_token else empty end')

if [ -z "$TOKEN" ]; then
  echo "Échec de connexion à Keycloak: $(echo "$TOKEN_RESPONSE" | jq -r 'if has("error_description") then .error_description else "Erreur inconnue" end')"
  exit 1
fi

# Récupération de l'UUID de l'utilisateur user1
echo "Récupération de l'UUID de l'utilisateur user1..."
USER_ID_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=user1" \
  -H "Authorization: Bearer $TOKEN")
USER_UUID=$(echo "$USER_ID_RESPONSE" | jq -r 'if type=="array" and length>0 then .[0].id else empty end')

if [ -z "$USER_UUID" ]; then
  echo "Impossible de trouver l'UUID de l'utilisateur user1."
  exit 1
fi

echo "UUID de l'utilisateur user1: $USER_UUID"

# Lecture du fichier de licence
echo "Lecture du fichier de licence..."
if [ ! -f "$LICENSE_FILE" ]; then
  echo "Fichier de licence non trouvé: $LICENSE_FILE"
  exit 1
fi

# Remplacement de l'UUID de l'utilisateur dans le fichier de licence
echo "Mise à jour des UUIDs utilisateur dans le fichier de licence..."
UPDATED_LICENSE=$(cat "$LICENSE_FILE" | sed "s/\"user_uuid\": \"d3f48a42-0d1e-4270-8e8e-549251cd823d\"/\"user_uuid\": \"$USER_UUID\"/g")

# Vérifier que MongoDB est accessible
echo "Vérification de la connexion à MongoDB..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if mongosh --host $MONGODB_HOST --port $MONGODB_PORT --eval "db.stats()" > /dev/null 2>&1; then
    echo "✔ Connexion à MongoDB établie"
    break
  else
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
      echo "Erreur: Impossible de se connecter à MongoDB après $MAX_RETRIES tentatives"
      exit 1
    fi
    echo "Tentative $RETRY_COUNT/$MAX_RETRIES: Connexion à MongoDB échouée, nouvelle tentative dans 2 secondes..."
    sleep 2
  fi
done

# Insertion des licences dans MongoDB
echo "Insertion des licences dans MongoDB..."
echo "$UPDATED_LICENSE" | mongoimport --host $MONGODB_HOST --port $MONGODB_PORT --db $MONGODB_DATABASE --collection $MONGODB_COLLECTION --drop --jsonArray

echo "✔ Initialisation des licences terminée"
