@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The name of the storage account.')
param storageAccountName string

@description('The name of the storage account default container.')
param defaultContainerName string

@description('The Fabric account principal ID.')
param fabricPrincipalId string = ''

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

@description('The client IP address.')
param clientIpAddress string = ''

@description('The tags to be applied to the provisioned resources.')
param tags object

// https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor
var roleStorageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var roleStorageBlobDataReader='2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
// var roleStorageFileContributor='69566ab7-960f-475b-8e7c-b3118f30c6bd'
var roleStorageFileReader='b8eda974-7b85-4f76-af95-65846b26df6d'


resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
    isHnsEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: clientIpAddress
          action: 'Allow'
        }
      ]
    }
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'Standard_RAGRS'
  }
  kind: 'StorageV2'
  tags: tags
}

resource storageFileSystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  name: '${storageAccount.name}/default/${defaultContainerName}'
  properties: {
    publicAccess: 'None'
  }
}

resource storageBlobRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, fabricPrincipalId, roleStorageBlobDataReader)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataReader)
    principalId: fabricPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageFileRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, fabricPrincipalId, roleStorageFileReader)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageFileReader)
    principalId: fabricPrincipalId
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

output outStorageAccountName string = storageAccount.name
output outStorageFilesysName string = storageFileSystem.name
