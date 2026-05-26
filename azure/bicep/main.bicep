targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name')
@allowed(['dev', 'staging', 'production'])
param environment string = 'staging'

@description('ACR name')
param acrName string = 'scalingfoodacr202605'

// Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Container Apps
module containerApps 'container-apps.bicep' = {
  name: 'container-apps'
  params: {
    location: location
    environment: environment
    acrName: acr.name
  }
}

// Redis
module redis 'redis.bicep' = {
  name: 'redis'
  params: {
    location: location
    environment: environment
  }
}

// MySQL
module mysql 'mysql.bicep' = {
  name: 'mysql'
  params: {
    location: location
    environment: environment
  }
}



output acrLoginServer string = acr.properties.loginServer
output foodCoreUrl string = containerApps.outputs.foodCoreFqdn
output notificationServiceUrl string = containerApps.outputs.notificationServiceFqdn
