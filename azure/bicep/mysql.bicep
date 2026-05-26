param location string = resourceGroup().location
param environment string
param adminUser string = 'foodadmin'
@secure()
param adminPassword string = 'ChangeMe123!@#'

var serverName = 'mysql-${environment}-${uniqueString(resourceGroup().id)}'

resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2023-06-30' = {
  name: serverName
  location: location
  sku: {
    name: environment == 'production' ? 'Standard_D4ds_v4' : 'Standard_B1ms'
    tier: environment == 'production' ? 'GeneralPurpose' : 'Burstable'
  }
  properties: {
    administratorLogin: adminUser
    administratorLoginPassword: adminPassword
    version: '8.0.21'
    highAvailability: {
      mode: environment == 'production' ? 'ZoneRedundant' : 'Disabled'
    }
    storage: {
      storageSizeGB: environment == 'production' ? 128 : 20
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: environment == 'production' ? 'Enabled' : 'Disabled'
    }
  }
}
