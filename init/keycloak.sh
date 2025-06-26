#!/bin/bash
set -e

KEYCLOAK_URL=http://karned-keycloak:8080
ADMIN_USERNAME=karned-admin
ADMIN_PASSWORD=topsecret
REALM=karned
CLIENT_ID=karned
CLIENT_SECRET=secret

echo "Attente du démarrage de Keycloak..."
until curl -s "$KEYCLOAK_URL/health/ready" > /dev/null; do
  sleep 2
done

echo "Connexion avec l'admin temporaire..."
TEMP_TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")
TEMP_TOKEN=$(echo "$TEMP_TOKEN_RESPONSE" | jq -r 'if has("access_token") then .access_token else empty end')

if [ -z "$TEMP_TOKEN" ]; then
  echo "Échec de connexion avec l'admin temporaire: $(echo "$TEMP_TOKEN_RESPONSE" | jq -r 'if has("error_description") then .error_description else "Erreur inconnue" end')"
  exit 1
fi

echo "Création de l'admin permanent..."
ADMIN_CREATE_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/master/users" \
  -H "Authorization: Bearer $TEMP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "'$ADMIN_USERNAME'",
    "enabled": true,
    "email": "admin@karned.com",
    "emailVerified": true,
    "credentials": [{"type": "password", "value": "'$ADMIN_PASSWORD'", "temporary": false}]
}')

if [ -n "$ADMIN_CREATE_RESPONSE" ]; then
  echo "Réponse de création de l'admin: $ADMIN_CREATE_RESPONSE"
  if echo "$ADMIN_CREATE_RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "Erreur lors de la création de l'admin: $(echo "$ADMIN_CREATE_RESPONSE" | jq -r '.error_description // .errorMessage // .error')"
    # Continue anyway, the admin might already exist
  fi
fi

sleep 5

ADMIN_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/master/users?username=$ADMIN_USERNAME" \
  -H "Authorization: Bearer $TEMP_TOKEN")
ADMIN_ID=$(echo "$ADMIN_RESPONSE" | jq -r 'if type=="array" and length>0 then .[0].id else empty end')

ADMIN_ROLE_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/master/roles" \
  -H "Authorization: Bearer $TEMP_TOKEN")
ADMIN_ROLE_ID=$(echo "$ADMIN_ROLE_RESPONSE" | jq -r 'if type=="array" then (.[] | select(.name=="admin") | .id) else empty end')

if [ -n "$ADMIN_ID" ] && [ -n "$ADMIN_ROLE_ID" ]; then
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/master/users/$ADMIN_ID/role-mappings/realm" \
    -H "Authorization: Bearer $TEMP_TOKEN" \
    -H "Content-Type: application/json" \
    -d '[{"id":"'$ADMIN_ROLE_ID'", "name":"admin"}]'
  echo "Rôle admin assigné."
else
  echo "Impossible d'assigner le rôle admin: ID utilisateur ou ID rôle manquant."
fi

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

echo "Suppression de l'admin temporaire..."
TEMP_ADMIN_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/master/users?username=admin" \
  -H "Authorization: Bearer $TOKEN")
TEMP_ADMIN_ID=$(echo "$TEMP_ADMIN_RESPONSE" | jq -r 'if type=="array" and length>0 then .[0].id else empty end')

if [ -n "$TEMP_ADMIN_ID" ]; then
  curl -s -X DELETE "$KEYCLOAK_URL/admin/realms/master/users/$TEMP_ADMIN_ID" \
    -H "Authorization: Bearer $TOKEN"
  echo "Admin temporaire supprimé."
else
  echo "Admin temporaire non trouvé."
fi

echo "Création du realm $REALM..."
REALM_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm":"'$REALM'", "enabled":true}')

if [ -n "$REALM_RESPONSE" ]; then
  echo "Réponse de création du realm: $REALM_RESPONSE"
  if echo "$REALM_RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "Erreur lors de la création du realm: $(echo "$REALM_RESPONSE" | jq -r '.error_description // .errorMessage // .error')"
    # Continue anyway, the realm might already exist
  fi
fi

echo "Création du client $CLIENT_ID..."
CLIENT_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/clients" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "'$CLIENT_ID'",
    "enabled": true,
    "publicClient": false,
    "directAccessGrantsEnabled": true,
    "redirectUris": ["*"],
    "webOrigins": ["*"],
    "clientAuthenticatorType": "client-secret",
    "secret": "'$CLIENT_SECRET'",
    "serviceAccountsEnabled": true,
    "standardFlowEnabled": true,
    "fullScopeAllowed": true
}')

if [ -n "$CLIENT_RESPONSE" ]; then
  echo "Réponse de création du client: $CLIENT_RESPONSE"
  if echo "$CLIENT_RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "Erreur lors de la création du client: $(echo "$CLIENT_RESPONSE" | jq -r '.error_description // .errorMessage // .error')"
    # Continue anyway, the client might already exist
  fi
fi

echo "Récupération de l'ID du client $CLIENT_ID..."
CLIENT_ID_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $TOKEN")
CLIENT_UUID=$(echo "$CLIENT_ID_RESPONSE" | jq -r 'if type=="array" and length>0 then .[0].id else empty end')

if [ -n "$CLIENT_UUID" ]; then
  echo "Création du protocol mapper pour l'audience..."
  MAPPER_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "audience-mapper",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-audience-mapper",
      "consentRequired": false,
      "config": {
        "included.client.audience": "'$CLIENT_ID'",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "included.custom.audience": "'$CLIENT_ID'"
      }
    }')
  echo "Réponse de création du mapper: $MAPPER_RESPONSE"
else
  echo "Impossible de trouver l'ID du client $CLIENT_ID."
fi

echo "Création du groupe karned-user..."
GROUP_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/groups" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "karned-user"
}')

if [ -n "$GROUP_RESPONSE" ]; then
  echo "Réponse de création du groupe: $GROUP_RESPONSE"
  if echo "$GROUP_RESPONSE" | jq -e 'has("error")' > /dev/null; then
    echo "Erreur lors de la création du groupe: $(echo "$GROUP_RESPONSE" | jq -r '.error_description // .errorMessage // .error')"
    # Continue anyway, the group might already exist
  fi
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

echo "Récupération de l'ID de l'utilisateur user1..."
USER_ID_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=user1" \
  -H "Authorization: Bearer $TOKEN")
USER_ID=$(echo "$USER_ID_RESPONSE" | jq -r 'if type=="array" and length>0 then .[0].id else empty end')

echo "Récupération de l'ID du groupe karned-user..."
GROUP_ID_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/groups?search=karned-user" \
  -H "Authorization: Bearer $TOKEN")
GROUP_ID=$(echo "$GROUP_ID_RESPONSE" | jq -r 'if type=="array" and length>0 then .[0].id else empty end')

if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
  echo "Ajout de l'utilisateur user1 au groupe karned-user..."
  JOIN_GROUP_RESPONSE=$(curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/users/$USER_ID/groups/$GROUP_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '')
  echo "Utilisateur ajouté au groupe."

  echo "Récupération de l'ID du client karned-client..."
  CLIENT_ID_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_ID" \
    -H "Authorization: Bearer $TOKEN")
  CLIENT_UUID=$(echo "$CLIENT_ID_RESPONSE" | jq -r 'if type=="array" and length>0 then .[0].id else empty end')

  if [ -n "$CLIENT_UUID" ]; then
    echo "Assignation de l'audience karned-client au groupe karned-user..."
    AUDIENCE_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/groups/$GROUP_ID/role-mappings/clients/$CLIENT_UUID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '[{
        "id": "'$CLIENT_UUID'",
        "name": "'$CLIENT_ID'"
      }]')
    echo "Audience assignée au groupe."
  else
    echo "Impossible de trouver l'ID du client karned-client."
  fi
else
  echo "Impossible d'ajouter l'utilisateur au groupe: ID utilisateur ou ID groupe manquant."
fi

echo "✔ Initialisation terminée"
