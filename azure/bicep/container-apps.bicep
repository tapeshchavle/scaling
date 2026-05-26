param location string = resourceGroup().location
param environment string
param acrName string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}
// Log Analytics Workspace for Container Apps
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'logs-${environment}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Container Apps Environment
resource managedEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'env-${environment}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// User Assigned Identity for ACR pull
resource acrPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-acrpull-${environment}'
  location: location
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, acr.id, acrPullIdentity.id, 'AcrPull')
  scope: acr
  properties: {
    principalId: acrPullIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
  }
}

// Food Core App
resource foodCore 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'food-core'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${acrPullIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8081
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: acrPullIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'food-core'
          image: '${acr.properties.loginServer}/food-core:latest'
          resources: {
            cpu: 1
            memory: '2.0Gi'
          }
          probes: [
            {
              type: 'liveness'
              httpGet: {
                port: 8081
                path: '/api/v1/food/health'
              }
              initialDelaySeconds: 40
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 2
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

// Notification Service App
resource notificationService 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'notification-service'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${acrPullIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8082
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: acrPullIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'notification-service'
          image: '${acr.properties.loginServer}/notification-service:latest'
          resources: {
            cpu: 1
            memory: '2.0Gi'
          }
          probes: [
            {
              type: 'liveness'
              httpGet: {
                port: 8082
                path: '/api/v1/notifications/health'
              }
              initialDelaySeconds: 40
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 2
        maxReplicas: 10
      }
    }
  }
}

output foodCoreFqdn string = foodCore.properties.configuration.ingress.fqdn
output notificationServiceFqdn string = notificationService.properties.configuration.ingress.fqdn
