#!/bin/bash
set -e

# Check if initialization has already been done
if [ -f "/app/flags/initialized" ]; then
    echo "Initialization already completed. Skipping..."
    exit 0
fi

# Make scripts executable
chmod +x /app/init/*.sh

# Run initialization script
cd /app
./init/container-init.sh

# Create flag file to indicate initialization is complete
touch /app/flags/initialized

echo "Initialization completed successfully!"