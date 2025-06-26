#!/bin/bash
set -e

# Wait a bit for services to be ready
echo "Waiting for services to be ready..."
sleep 30

# Execute the initialization scripts
echo "Initializing Redis..."
/app/init/redis.sh

echo "Initializing Vault..."
/app/init/vault.sh

echo "Initializing Keycloak..."
/app/init/keycloak.sh

echo "Initializing Licenses..."
/app/init/license.sh

echo "Initializing Recipes..."
/app/init/recipe.sh

echo "Initialization completed successfully!"