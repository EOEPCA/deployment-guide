#!/bin/bash

DEFAULT_COLLECTIONS_FILE="./collections.json"
DEFAULT_ITEMS_FILE="./items.json"

if [ "$#" -eq 2 ]; then
    EOAPI_COLLECTIONS_FILE="$1"
    EOAPI_ITEMS_FILE="$2"
else
    EOAPI_COLLECTIONS_FILE="$DEFAULT_COLLECTIONS_FILE"
    EOAPI_ITEMS_FILE="$DEFAULT_ITEMS_FILE"
    echo "No specific files provided. Using defaults:"
    echo "  Collections file: $EOAPI_COLLECTIONS_FILE"
    echo "  Items file: $EOAPI_ITEMS_FILE"
fi

NAMESPACES=("default" "eoapi", "data-access")
EOAPI_POD_RASTER=""
FOUND_NAMESPACE=""

for NS in "${NAMESPACES[@]}"; do
    EOAPI_POD_RASTER=$(kubectl get pods -n "$NS" -l app=eoapi-raster -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
    if [ -n "$EOAPI_POD_RASTER" ]; then
        FOUND_NAMESPACE="$NS"
        echo "Found raster-eoapi pod: $EOAPI_POD_RASTER in namespace: $FOUND_NAMESPACE"
        break
    fi
done

if [ -z "$EOAPI_POD_RASTER" ]; then
    echo "Could not determine raster-eoapi pod."
    exit 1
fi

for FILE in "$EOAPI_COLLECTIONS_FILE" "$EOAPI_ITEMS_FILE"; do
    if [ ! -f "$FILE" ]; then
        echo "File not found: $FILE. You may set them via the EOAPI_COLLECTIONS_FILE and EOAPI_ITEMS_FILE environment variables."
        exit 1
    fi
done

echo "Installing required packages in pod $EOAPI_POD_RASTER in namespace $FOUND_NAMESPACE..."
if ! kubectl exec -n "$FOUND_NAMESPACE" "$EOAPI_POD_RASTER" -- bash -c 'pip install --user "pypgstac[psycopg]"'; then
    echo "Failed to install packages."
    exit 1
fi

echo "Copying files to pod..."
echo "Using collections file: $EOAPI_COLLECTIONS_FILE"
echo "Using items file: $EOAPI_ITEMS_FILE"
kubectl cp "$EOAPI_COLLECTIONS_FILE" "$FOUND_NAMESPACE/$EOAPI_POD_RASTER":/tmp/collections.json
kubectl cp "$EOAPI_ITEMS_FILE" "$FOUND_NAMESPACE/$EOAPI_POD_RASTER":/tmp/items.json

echo "Loading collections..."
if ! kubectl exec -n "$FOUND_NAMESPACE" "$EOAPI_POD_RASTER" -- bash -c 'export PATH="$PATH:$HOME/.local/bin"; pypgstac load collections /tmp/collections.json --dsn "$PGADMIN_URI" --method insert_ignore'; then
    echo "Failed to load collections."
    exit 1
fi

echo "Loading items..."
if ! kubectl exec -n "$FOUND_NAMESPACE" "$EOAPI_POD_RASTER" -- bash -c 'export PATH="$PATH:$HOME/.local/bin"; pypgstac load items /tmp/items.json --dsn "$PGADMIN_URI" --method insert_ignore'; then
    echo "Failed to load items."
    exit 1
fi

echo "Cleaning temporary files..."
kubectl exec -n "$FOUND_NAMESPACE" "$EOAPI_POD_RASTER" -- bash -c 'rm -f /tmp/collections.json /tmp/items.json'

echo "Ingestion complete."
