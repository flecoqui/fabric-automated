// Parameters
@description('The name of the Synapse workspace')
param workspaceName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('The name of the default storage account for Synapse')
param defaultStorageAccountName string

@description('The name of the default file system (container) in the storage account')
param defaultFileSystemName string = 'synapsefs'

@description('The SQL administrator login username')
param sqlAdministratorLogin string

@description('The SQL administrator login password')
@secure()
param sqlAdministratorPassword string

@description('The name of the dedicated SQL pool')
param sqlPoolName string = 'dedicatedSqlPool'

@description('The SKU name for the dedicated SQL pool')
@allowed([
  'DW100c'
  'DW200c'
  'DW300c'
  'DW400c'
  'DW500c'
  'DW1000c'
  'DW1500c'
  'DW2000c'
  'DW2500c'
  'DW3000c'
])
param sqlPoolSku string = 'DW100c'

@description('The name of the Apache Spark pool')
param sparkPoolName string = 'sparkPool'

@description('The node size for the Spark pool')
@allowed([
  'Small'
  'Medium'
  'Large'
  'XLarge'
  'XXLarge'
])
param sparkPoolNodeSize string = 'Small'

@description('The minimum number of nodes for the Spark pool')
@minValue(3)
param sparkPoolMinNodeCount int = 3

@description('The maximum number of nodes for the Spark pool')
@minValue(3)
param sparkPoolMaxNodeCount int = 10

@description('Enable auto-scale for the Spark pool')
param sparkPoolAutoScaleEnabled bool = true

@description('Enable auto-pause for the Spark pool')
param sparkPoolAutoPauseEnabled bool = true

@description('Auto-pause delay in minutes')
param sparkPoolAutoPauseDelayInMinutes int = 15

@description('Apache Spark version')
@allowed([
  '2.4'
  '3.1'
  '3.2'
  '3.3'
  '3.4'
])
param sparkVersion string = '3.3'

@description('The Fabric account principal ID.')
param purviewPrincipalId string = ''

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

@description('The client IP address.')
param clientIpAddress string = ''

@description('The tags to be applied to the provisioned resources.')
param tags object

// Variables
var roleStorageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var roleStorageBlobDataReader='2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
// var roleStorageFileContributor='69566ab7-960f-475b-8e7c-b3118f30c6bd'
var roleStorageFileReader='b8eda974-7b85-4f76-af95-65846b26df6d'
var roleSynapseReader='acdd72a7-3385-48ef-bd42-f606fba81ae7'

// Storage Account for Synapse default storage
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: defaultStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true // Enable hierarchical namespace (Data Lake Gen2)
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: [
        {
          value: clientIpAddress
          action: 'Allow'
        }
      ]
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
}

// Blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Default file system (container) for Synapse
resource fileSystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: defaultFileSystemName
  properties: {
    publicAccess: 'None'
  }
}

// Synapse Workspace
resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: storageAccount.properties.primaryEndpoints.dfs
      filesystem: defaultFileSystemName
    }
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorPassword
    managedResourceGroupName: '${workspaceName}-managed-rg'
    publicNetworkAccess: 'Enabled'
  }
  dependsOn: [
    fileSystem
  ]
}

// Grant Synapse workspace managed identity Storage Blob Data Contributor role on the storage account
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, synapseWorkspace.id, roleStorageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataContributor)
    principalId: synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Firewall rule to allow all Azure services
resource firewallAllowAllAzure 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: synapseWorkspace
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Optional: Firewall rule to allow all IPs (for development/testing only)
resource firewallAllowAll 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: synapseWorkspace
  name: 'AllowAll'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// Dedicated SQL Pool
resource sqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  parent: synapseWorkspace
  name: sqlPoolName
  location: location
  tags: tags
  sku: {
    name: sqlPoolSku
  }
  properties: {
    createMode: 'Default'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

// Apache Spark Pool
resource sparkPool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = {
  parent: synapseWorkspace
  name: sparkPoolName
  location: location
  tags: tags
  properties: {
    nodeCount: sparkPoolAutoScaleEnabled ? 0 : sparkPoolMinNodeCount
    nodeSizeFamily: 'MemoryOptimized'
    nodeSize: sparkPoolNodeSize
    autoScale: {
      enabled: sparkPoolAutoScaleEnabled
      minNodeCount: sparkPoolMinNodeCount
      maxNodeCount: sparkPoolMaxNodeCount
    }
    autoPause: {
      enabled: sparkPoolAutoPauseEnabled
      delayInMinutes: sparkPoolAutoPauseDelayInMinutes
    }
    sparkVersion: sparkVersion
    dynamicExecutorAllocation: {
      enabled: true
      minExecutors: 1
      maxExecutors: sparkPoolMaxNodeCount-1
    }
    isComputeIsolationEnabled: false
    sessionLevelPackagesEnabled: true
    cacheSize: 0
  }
}

resource storageBlobRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, purviewPrincipalId, roleStorageBlobDataReader)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataReader)
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageFileRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, purviewPrincipalId, roleStorageFileReader)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageFileReader)
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobRoleAssignment2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, objectId, roleStorageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataContributor)
    principalId: objectId
    principalType: objectType
  }
}

resource synapseReaderRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(synapseWorkspace.id, purviewPrincipalId, roleSynapseReader)
  scope: synapseWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSynapseReader)
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output synapseWorkspaceId string = synapseWorkspace.id
output synapseWorkspaceName string = synapseWorkspace.name
output synapseWorkspaceEndpoint string = synapseWorkspace.properties.connectivityEndpoints.dev
output synapseSqlEndpoint string = synapseWorkspace.properties.connectivityEndpoints.sql
output synapseSqlOnDemandEndpoint string = synapseWorkspace.properties.connectivityEndpoints.sqlOnDemand
output sqlPoolId string = sqlPool.id
output sqlPoolName string = sqlPool.name
output sparkPoolId string = sparkPool.id
output sparkPoolName string = sparkPool.name
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output defaultFileSystemName string = defaultFileSystemName
output workspaceManagedIdentityPrincipalId string = synapseWorkspace.identity.principalId
