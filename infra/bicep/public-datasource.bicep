@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The Azure Environment (dev, staging, preprod, prod,...)')
@maxLength(7)
param env string = 'dev'

@description('The cloud visibility (pub, pri)')
@maxLength(7)
param visibility string = 'pub'

@description('The Azure suffix')
@maxLength(4)
param suffix string = '0000'

@description('The Sql administrator login of the administrator account.')
param sqlAdministratorLogin string

@description('The Sql administrator password of the administrator account.')
@secure()
param sqlAdministratorPassword string

@description('The Fabric account principal ID.')
param purviewPrincipalId string = ''

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

@description('The client IP address.')
param clientIpAddress string = ''

module namingModule 'naming-convention.bicep' = {
  name: 'namingModule'
  params: {
    environment: env
    visibility: visibility
    suffix: suffix
  }
}

var tags = {
  baseName : namingModule.outputs.baseName
  environment: env
  visibility: visibility
  suffix: suffix
}


module storage 'public-storage.bicep' = {
  name: 'StorageDeploy'
  scope: resourceGroup()
  params: {
    location: location
    storageAccountName: namingModule.outputs.storageAccountName
    defaultContainerName: namingModule.outputs.storageAccountDefaultContainerName
    purviewPrincipalId: purviewPrincipalId
    objectId: objectId
    objectType: objectType
    clientIpAddress: clientIpAddress
    tags: tags
  }
  dependsOn: [
  ]
}

// Reference existing Key Vault
// resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
//  name: namingModule.outputs.keyVaultName
//  scope: resourceGroup(namingModule.outputs.resourceGroupPurviewName)
//}

// Use the secret in a parameter
// var sqlAdministratorLogin = listSecrets(resourceId(namingModule.outputs.resourceGroupPurviewName, 'Microsoft.KeyVault/vaults/secrets', namingModule.outputs.keyVaultName, namingModule.outputs.synapseSqlAdministratorLoginSecretName), '2023-07-01').value
// var sqlAdministratorPassword = listSecrets(resourceId(namingModule.outputs.resourceGroupPurviewName, 'Microsoft.KeyVault/vaults/secrets', namingModule.outputs.keyVaultName, namingModule.outputs.synapseSqlAdministratorPassSecretName), '2023-07-01').value

// var sqlAdministratorLogin string = keyVault.getSecret(namingModule.outputs.synapseSqlAdministratorLoginSecretName)
// var sqlAdministratorPassword string = keyVault.getSecret(namingModule.outputs.synapseSqlAdministratorPassSecretName)


module synapse 'public-synapse-workspace.bicep' = {
  name: 'SynapseDeploy'
  scope: resourceGroup()
  params: {
    workspaceName: namingModule.outputs.synapseWorkspaceName
    location: location
    defaultStorageAccountName: namingModule.outputs.synapseStorageAccountName
    defaultFileSystemName: namingModule.outputs.synapseFileSystemName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlPoolName: namingModule.outputs.synapseSqlPoolName
    sqlPoolSku: namingModule.outputs.synapseSqlPoolSku
    sparkPoolName: namingModule.outputs.synapseSparkPoolName
    sparkPoolNodeSize: namingModule.outputs.synapseSparkPoolNodeSize
    sparkPoolMinNodeCount: namingModule.outputs.synapseSparkPoolMinNodeCount
    sparkPoolMaxNodeCount: namingModule.outputs.synapseSparkPoolMaxNodeCount
    sparkPoolAutoScaleEnabled: namingModule.outputs.synapseSparkPoolAutoScaleEnabled
    sparkPoolAutoPauseEnabled: namingModule.outputs.synapseSparkPoolAutoPauseEnabled
    sparkPoolAutoPauseDelayInMinutes: namingModule.outputs.synapseSparkPoolAutoPauseDelayInMinutes
    sparkVersion: namingModule.outputs.synapseSparkVersion
    purviewPrincipalId: purviewPrincipalId
    objectId: objectId
    objectType: objectType
    clientIpAddress: clientIpAddress
    tags: tags
  }
  dependsOn: [
  ]
}

output outStorageAccountName string = storage.outputs.outStorageAccountName
output outStorageFilesysName string = storage.outputs.outStorageFilesysName
output synapseWorkspaceId string = synapse.outputs.synapseWorkspaceId
output synapseWorkspaceName string = synapse.outputs.synapseWorkspaceName
output synapseWorkspaceEndpoint string = synapse.outputs.synapseWorkspaceEndpoint
output synapseSqlEndpoint string = synapse.outputs.synapseSqlEndpoint
output synapseSqlOnDemandEndpoint string = synapse.outputs.synapseSqlOnDemandEndpoint
output synapseSqlPoolId string = synapse.outputs.sqlPoolId
output synapseSqlPoolName string = synapse.outputs.sqlPoolName
output synapseSparkPoolId string = synapse.outputs.sparkPoolId
output synapseSparkPoolName string = synapse.outputs.sparkPoolName
output synapseStorageAccountId string = synapse.outputs.storageAccountId
output synapseStorageAccountName string = synapse.outputs.storageAccountName
output synapseDefaultFileSystemName string = synapse.outputs.defaultFileSystemName
output synapseWorkspaceManagedIdentityPrincipalId string = synapse.outputs.workspaceManagedIdentityPrincipalId
