#!/bin/bash

# Attendre que Keycloak soit prêt
echo "Attente du démarrage de Keycloak..."
while ! curl -s http://localhost:5990/health/ready; do
  sleep 5
done

# Essayer d'obtenir un token avec l'admin permanent
echo "Tentative d'obtention du token avec l'admin permanent..."
TOKEN=$(curl -s -X POST http://localhost:5990/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=karned-admin" \
  -d "password=K@rn3dAdm1n2023" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

# Vérifier si le token est valide
if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
  echo "Token obtenu avec l'admin permanent."
else
  # Si le token n'est pas valide, essayer avec l'admin temporaire
  echo "Échec de l'obtention du token avec l'admin permanent. Tentative avec l'admin temporaire..."
  TEMP_TOKEN=$(curl -s -X POST http://localhost:5990/realms/master/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin" \
    -d "password=admin" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

  # Vérifier si le token temporaire est valide
  if [ "$TEMP_TOKEN" != "null" ] && [ -n "$TEMP_TOKEN" ]; then
    echo "Token obtenu avec l'admin temporaire."

    # Créer un nouvel utilisateur admin permanent
    echo "Création d'un compte admin permanent..."
    curl -s -X POST http://localhost:5990/admin/realms/master/users \
      -H "Authorization: Bearer $TEMP_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"username":"karned-admin", "enabled":true, "email":"admin@karned.com", "emailVerified": true, "requiredActions":[], "credentials":[{"type":"password","value":"K@rn3dAdm1n2023", "temporary":false}]}'

    # Attendre un moment pour que Keycloak traite la création de l'utilisateur admin
    echo "Attente du traitement de la création de l'admin permanent..."
    sleep 3

    # Récupérer l'ID de l'utilisateur admin
    echo "Récupération de l'ID de l'admin permanent..."
    ADMIN_ID=$(curl -s -X GET http://localhost:5990/admin/realms/master/users?username=karned-admin \
      -H "Authorization: Bearer $TEMP_TOKEN" | jq -r '.[0].id')

    # Vérifier si l'ID de l'admin a été récupéré
    if [ -n "$ADMIN_ID" ]; then
      echo "ID de l'admin permanent récupéré: $ADMIN_ID"

      # Récupérer l'ID du rôle admin
      echo "Récupération de l'ID du rôle admin..."
      ADMIN_ROLE_ID=$(curl -s -X GET http://localhost:5990/admin/realms/master/roles \
        -H "Authorization: Bearer $TEMP_TOKEN" | jq -r '.[] | select(.name=="admin") | .id')

      # Attribuer le rôle admin au nouvel utilisateur admin
      echo "Attribution du rôle admin au nouvel utilisateur admin..."
      curl -s -X POST http://localhost:5990/admin/realms/master/users/$ADMIN_ID/role-mappings/realm \
        -H "Authorization: Bearer $TEMP_TOKEN" \
        -H "Content-Type: application/json" \
        -d '[{"id":"'$ADMIN_ROLE_ID'","name":"admin"}]'

      # Obtenir un token d'accès avec le nouvel admin
      echo "Obtention du token avec le nouvel admin..."
      TOKEN=$(curl -s -X POST http://localhost:5990/realms/master/protocol/openid-connect/token \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=karned-admin" \
        -d "password=K@rn3dAdm1n2023" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r '.access_token')

      # Récupérer l'ID de l'utilisateur admin temporaire
      echo "Récupération de l'ID de l'admin temporaire..."
      TEMP_ADMIN_ID=$(curl -s -X GET http://localhost:5990/admin/realms/master/users?username=admin \
        -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

      # Supprimer l'utilisateur admin temporaire
      if [ -n "$TEMP_ADMIN_ID" ]; then
        echo "Suppression de l'admin temporaire..."
        curl -s -X DELETE http://localhost:5990/admin/realms/master/users/$TEMP_ADMIN_ID \
          -H "Authorization: Bearer $TOKEN"
        echo "Admin temporaire supprimé avec succès!"
      else
        echo "Erreur: Impossible de récupérer l'ID de l'admin temporaire."
      fi
    else
      echo "Erreur: Impossible de récupérer l'ID de l'admin permanent."
      exit 1
    fi
  else
    echo "Erreur: Impossible d'obtenir un token avec l'admin temporaire."
    exit 1
  fi
fi

# Vérifier si le realm karned existe déjà
REALM_EXISTS=$(curl -s -X GET http://localhost:5990/admin/realms \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.realm=="karned") | .realm')

if [ "$REALM_EXISTS" != "karned" ]; then
  # Créer le realm
  echo "Création du realm karned..."
  curl -s -X POST http://localhost:5990/admin/realms \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"realm":"karned", "enabled":true}'
else
  echo "Le realm karned existe déjà."
fi

# Vérifier si le client karned-client existe déjà
CLIENT_EXISTS=$(curl -s -X GET http://localhost:5990/admin/realms/karned/clients \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.clientId=="karned-client") | .clientId')

if [ "$CLIENT_EXISTS" != "karned-client" ]; then
  # Créer un client
  echo "Création d'un client..."
  curl -s -X POST http://localhost:5990/admin/realms/karned/clients \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"clientId":"karned-client", "enabled":true, "publicClient":false, "directAccessGrantsEnabled":true, "redirectUris":["*"], "webOrigins":["*"], "clientAuthenticatorType":"client-secret", "secret":"secret"}'
else
  echo "Le client karned-client existe déjà. Mise à jour de la configuration..."
  # Récupérer l'ID du client
  CLIENT_ID=$(curl -s -X GET http://localhost:5990/admin/realms/karned/clients \
    -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.clientId=="karned-client") | .id')

  # Mettre à jour le client pour activer l'authentification client
  curl -s -X PUT http://localhost:5990/admin/realms/karned/clients/$CLIENT_ID \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"clientId":"karned-client", "enabled":true, "publicClient":false, "directAccessGrantsEnabled":true, "redirectUris":["*"], "webOrigins":["*"], "clientAuthenticatorType":"client-secret", "secret":"secret"}'

  echo "Client mis à jour avec succès!"
fi

# Vérifier si l'utilisateur user1 existe déjà
USER_EXISTS=$(curl -s -X GET http://localhost:5990/admin/realms/karned/users?username=user1 \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].username')

if [ "$USER_EXISTS" != "user1" ]; then
  # Créer un utilisateur
  echo "Création d'un utilisateur..."
  curl -s -X POST http://localhost:5990/admin/realms/karned/users \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"username":"user1", "enabled":true, "email":"user1@example.com", "emailVerified": true, "requiredActions":[], "credentials":[{"type":"password","value":"password","temporary":false}]}'

  # Attendre un moment pour que Keycloak traite la création de l'utilisateur
  echo "Attente du traitement de la création de l'utilisateur..."
  sleep 3
else
  echo "L'utilisateur user1 existe déjà."
fi

# Récupérer l'ID de l'utilisateur
echo "Récupération de l'ID de l'utilisateur..."
USER_ID=$(curl -s -X GET http://localhost:5990/admin/realms/karned/users?username=user1 \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# Vérifier si l'ID de l'utilisateur a été récupéré
if [ -n "$USER_ID" ]; then
  echo "ID de l'utilisateur récupéré: $USER_ID"

  # Mettre à jour les informations de l'utilisateur pour s'assurer qu'il n'y a pas d'actions requises
  echo "Mise à jour des informations de l'utilisateur..."
  curl -s -X PUT http://localhost:5990/admin/realms/karned/users/$USER_ID \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"username":"user1", "enabled":true, "email":"user1@example.com", "emailVerified": true, "requiredActions":[]}'

  echo "Utilisateur mis à jour avec succès!"
else
  echo "Erreur: Impossible de récupérer l'ID de l'utilisateur."
fi

echo "Initialisation de Keycloak terminée!"
