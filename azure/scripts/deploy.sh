#!/bin/bash
set -euo pipefail

# Azure Deployment Script
RESOURCE_GROUP="scaling-food-rg-uae"
LOCATION="uaenorth"
ENVIRONMENT="staging"

echo "Creating Resource Group: $RESOURCE_GROUP in $LOCATION"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "Deploying Bicep Templates..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file azure/bicep/main.bicep \
  --parameters environment="$ENVIRONMENT" \
  --query 'properties.outputs' \
  --output json > deployment-outputs.json

ACR_LOGIN_SERVER=$(jq -r '.acrLoginServer.value' deployment-outputs.json)
FOOD_CORE_URL=$(jq -r '.foodCoreUrl.value' deployment-outputs.json)
NOTIFICATION_URL=$(jq -r '.notificationServiceUrl.value' deployment-outputs.json)

echo "ACR Login Server: $ACR_LOGIN_SERVER"
echo "Food Core URL: $FOOD_CORE_URL"
echo "Notification Service URL: $NOTIFICATION_URL"

echo "Deployment completed successfully!"
