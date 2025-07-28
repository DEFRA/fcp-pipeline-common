param identityName string
param location string = resourceGroup().location
param issuer string
param subject string
param federationName string
param audiences array = [
  'api://AzureADTokenExchange'
]

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
output identityResourceId string = identity.id
output identityClientId string = identity.properties.clientId

