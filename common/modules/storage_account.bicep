
param targetEnvironment string
param subscriptionSpoke string
param identityName string
param storage object
param location string = resourceGroup().location
param baseTime string = utcNow('yyyyMMdd')
param environmentDescription string

resource storageResource 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  kind: 'StorageV2'
  location: location
  name: toLower('${environmentDescription}FFC${storage.name}ST${subscriptionSpoke}001')
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  sku: {
    name: 'Standard_LRS'
  }
  tags: {
    displayName: toLower('${environmentDescription}FFC${storage.name}ST${subscriptionSpoke}001')
    Name: toLower('${environmentDescription}FFC${storage.name}ST${subscriptionSpoke}001')
    CreatedBy: 'FCP Pipeline Common'
    ServiceCode: 'FFC'
    ServiceName: 'FutureFarming'
    CreatedDate: baseTime
    ServiceType: 'LOB'
    Environment: targetEnvironment
    Tier: 'StorageAccount'
    Location: location
  }
}

// Loop over roles
module roleAssignmentModules 'storage_account_roleAssignment.bicep' = [
  for role in storage.?roles ?? []: {
    params: {
      storageName: storageResource.name
      identityName: identityName
      role: role.name
    }
  }
]

resource blobServiceResource 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storageResource
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 7
    }
  }
}

resource fileServiceResource 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: storageResource
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource queueServiceResource 'Microsoft.Storage/storageAccounts/queueServices@2025-01-01' = {
  parent: storageResource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource tableServiceResource 'Microsoft.Storage/storageAccounts/tableServices@2025-01-01' = {
  parent: storageResource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

// Loop over containers
module containerModules 'storage_account_container.bicep' = [
  for container in storage.?containers ?? []: {
    params: {
      storageName: toLower('${environmentDescription}FFC${storage.name}ST${subscriptionSpoke}001')
      container: container
      identityName: identityName
    }
  }
]

// Loop over queues
module queueModules 'storage_account_queue.bicep' = [
  for queue in storage.?queues ?? []: {
    params: {
      storageName: toLower('${environmentDescription}FFC${storage.name}ST${subscriptionSpoke}001')
      queue: queue
      identityName: identityName
    }
  }
]

// Loop over tables
module tableModules 'storage_account_table.bicep' = [
  for table in storage.?tables ?? []: {
    params: {
      storageName: toLower('${environmentDescription}FFC${storage.name}ST${subscriptionSpoke}001')
      table: table
      identityName: identityName
    }
  }
]
