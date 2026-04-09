#!/bin/bash

# Define variables
STORAGE_ACCOUNT="ziplineai2"
CONTAINER_NAME="dev-zipline-vars"
BLOB_PATH_PREFIX="zipline-base"

FILES=(
    "dev_backend.tf"
    "dev_divergences.tf"
    ".terraform.lock.hcl"
    "terraform.tfvars"
)

echo "Pushing dev configuration files to Azure Storage..."

for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        echo "Uploading $FILE..."
        az storage blob upload \
            --account-name "$STORAGE_ACCOUNT" \
            --container-name "$CONTAINER_NAME" \
            --name "$BLOB_PATH_PREFIX/$FILE" \
            --file "$FILE" \
            --overwrite \
            --auth-mode login
    else
        echo "Warning: $FILE not found, skipping."
    fi
done