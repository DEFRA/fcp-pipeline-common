param targetEnvironment string
param subscriptionSpoke string
// Managed Identity and Federated Identity Credential
@description('Managed Identity name')
param identityName string
@description('Azure location for the resources')
param location string = resourceGroup().location
@description('Kubernetes issuer URL for the federated identity')
param issuer string
@description('Kubernetes subject for the federated identity')
param subject string
@description('Federated name')
param federationName string
// *****
@description('Audiences for the federated identity')
var audiences = [
  'api://AzureADTokenExchange'
]

// Service Bus
@description('List of queues')
param queues array
param hasQueues bool

// @description('Subscription ID')
// param subscriptionId string = subscription().subscriptionId


resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: identityName
  location: location
}

resource federatedCred 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  name: federationName
  parent: identity
  properties: {
    issuer: issuer
    subject: subject
    audiences: audiences
  }
}

// Creating a symbolic name for an existing resource
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' existing = {
  name: '${targetEnvironment}FFCINFSB${subscriptionSpoke}001'
}

resource queuesResources 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = [
  for queue in queues: if (hasQueues) {
    name: '${queue.name}-${queue.suffix}'
    parent: serviceBusNamespace
    properties: {
      lockDuration: queue.lockDuration ?? 'PT30S'
      maxSizeInMegabytes: queue.maxSize ?? 5120
      requiresDuplicateDetection: queue.duplicateDetection ?? false
      duplicateDetectionHistoryTimeWindow: 'PT10M'
      defaultMessageTimeToLive: queue.messageTimeToLive ?? 'P14D'
      requiresSession: queue.session ?? false
      enablePartitioning: queue.partitioning ?? false
    }
  }
]

// Role assignment IDs
// var senderRoleId = subscriptionResourceId(
//   'Microsoft.Authorization/roleDefinitions',
//   '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
// )
// var receiverRoleId = subscriptionResourceId(
//   'Microsoft.Authorization/roleDefinitions',
//   'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
// )

// resource senderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
//   for (queue, i) in queues: if (hasQueues && (queue.role == 'sender' || queue.role == 'senderAndReceiver')) {
//     name: guid(queue.name, identity.name, 'sender')
//     scope: queuesResources[i]
//     properties: {
//       principalId: identity.properties.principalId
//       roleDefinitionId: senderRoleId
//       principalType: 'ServicePrincipal'
//     }
//   }
// ]

// resource receiverRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
//   for (queue, i) in queues: if (hasQueues && (queue.role == 'receiver' || queue.role == 'senderAndReceiver')) {
//     name: guid(queue.name, identity.name, 'receiver')
//     scope: queuesResources[i]
//     properties: {
//       principalId: identity.properties.clientId
//       roleDefinitionId: receiverRoleId
//       principalType: 'ServicePrincipal'
//     }
//   }
// ]

output identityResourceId string = identity.id
output identityClientId string = identity.properties.clientId
