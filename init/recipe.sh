#!/bin/bash
set -e

MONGODB_HOST=localhost
MONGODB_PORT=5971
MONGODB_DATABASE=karned
MONGODB_COLLECTION=recipes
RECIPES_FILE="../data/rekipe.recipes.json"

echo "Initialisation des recettes..."

# Lecture du fichier de recettes
echo "Lecture du fichier de recettes..."
if [ ! -f "$RECIPES_FILE" ]; then
  echo "Fichier de recettes non trouvé: $RECIPES_FILE"
  exit 1
fi

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

# Insertion des recettes dans MongoDB
echo "Insertion des recettes dans MongoDB..."
mongoimport --host $MONGODB_HOST --port $MONGODB_PORT --db $MONGODB_DATABASE --collection $MONGODB_COLLECTION --drop --jsonArray --file "$RECIPES_FILE"

echo "✔ Initialisation des recettes terminée"