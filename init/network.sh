#!/bin/bash

# Script to create the karned network for Docker

# Check if the network already exists
if docker network inspect karned-network &>/dev/null; then
    echo "The karned-network already exists."
else
    # Create the network
    echo "Creating karned-network..."
    docker network create karned-network
    echo "karned-network created successfully."
fi

echo "You can now run docker-compose up to start the services."