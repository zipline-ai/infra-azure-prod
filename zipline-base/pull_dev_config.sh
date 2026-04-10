#!/bin/bash
set -euo pipefail

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

echo "Pulling dev configuration files from Azure Storage..."

for FILE in "${FILES[@]}"; do
    echo "Downloading $FILE..."
    if ! az storage blob download \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name "$CONTAINER_NAME" \
        --name "$BLOB_PATH_PREFIX/$FILE" \
        --file "$FILE" \
        --auth-mode login; then
      echo "Error: failed to download $FILE" >&2
      exit 1
    fi
done