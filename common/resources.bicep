// General Parameters
param targetEnvironment string
param subscriptionSpoke string
param altEnvironment string

// param identityName string
@description('Azure location for the resources')
param location string = resourceGroup().location
@description('Kubernetes issuer URL for the federated identity')
param issuer string
@description('Kubernetes subject for the federated identity')
param subject string
@description('Federated name')
param federationName string

param resourcesObject object

param baseTime string = utcNow('yyyyMMdd')

// Variables
@description('Audiences for the federated identity')
var audiences = [
  'api://AzureADTokenExchange'
]

var managedIdentityPrefix = '${targetEnvironment}FFCINFMID${subscriptionSpoke}001'

// Creating managed Identity
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: '${managedIdentityPrefix}-${resourcesObject.resources.identity}'
  location: location
  tags: {
    Name: '${managedIdentityPrefix}-${resourcesObject.resources.identity}'
    CreatedBy: 'FCP Pipeline Common'
    ServiceCode: 'FFC'
    ServiceName: 'FutureFarming'
    CreatedDate: baseTime
    ServiceType: 'LOB'
    Environment: targetEnvironment
    Tier: 'ManagedIdentity'
    Location: location
  }
}

// Creating a federated identity credential for the managed identity
resource federatedCred 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  name: federationName
  parent: identity
  properties: {
    issuer: issuer
    subject: subject
    audiences: audiences
  }
}

//  Creating queues
module queueModule 'modules/queue.bicep' = [
  for queue in resourcesObject.resources.?queues ?? []: {
    params: {
      queue: queue
      altEnvironment: altEnvironment
      subscriptionSpoke: subscriptionSpoke
      targetEnvironment: targetEnvironment
      identityClientId: identity.properties.clientId
      // identityName: identity.name
    }
  }
]

// Creating topics and subscriptions
module topicModule 'modules/topic.bicep' = [
  for topic in resourcesObject.resources.?topics ?? []: {
    params: {
      topic: topic
      altEnvironment: altEnvironment
      subscriptionSpoke: subscriptionSpoke
      targetEnvironment: targetEnvironment
      identityClientId: identity.properties.clientId
      // identityName: identity.name
    }
  }
]

output queueRoleCreates array = [
  for i in range(0, length(resourcesObject.resources.?queues ?? [])): concat(queueModule[i].outputs.roleCreates)
]

output topicRoleCreates array = [
  for i in range(0, length(resourcesObject.resources.?topics ?? [])): concat(topicModule[i].outputs.roleCreates)
]

output identityResourceId string = identity.id
output identityClientId string = identity.properties.clientId
output identityName string = identity.name
