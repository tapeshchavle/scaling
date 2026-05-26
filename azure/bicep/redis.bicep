param location string = resourceGroup().location
param environment string

var skuName = environment == 'production' ? 'Premium' : 'Standard'
var skuFamily = environment == 'production' ? 'P' : 'C'
var skuCapacity = environment == 'production' ? 1 : 0

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: 'redis-${environment}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: skuName
      family: skuFamily
      capacity: skuCapacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}
