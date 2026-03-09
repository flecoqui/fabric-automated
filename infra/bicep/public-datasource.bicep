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
param fabricPrincipalId string = ''

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

// Azure Key Vault related variables
// var keyVaultName = namingModule.outputs.keyVaultName

// module keyVaultModule 'public-keyvault.bicep' = {
//   name: 'keyVaultDeploy'
//   scope: resourceGroup()
//   params: {
//     location: location
//     keyVaultName: keyVaultName
//     clientIpAddress: clientIpAddress
//     tags: tags
//   }
// }

module storageModule 'public-storage.bicep' = {
  name: 'StorageDeploy'
  scope: resourceGroup()
  params: {
    location: location
    storageAccountName: namingModule.outputs.storageAccountName
    defaultContainerName: namingModule.outputs.storageAccountDefaultContainerName
    fabricPrincipalId: fabricPrincipalId
    objectId: objectId
    objectType: objectType
    clientIpAddress: clientIpAddress
    tags: tags
  }
  dependsOn: [
  ]
}

// Add Foundry project
// Add PostgreSQL
// Add Cosmos DB


// Reference existing Key Vault
// resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
//  name: keyVaultName
//  scope: resourceGroup(namingModule.outputs.resourceGroupFabricName)
// }

// Use the secret in a parameter
// var sqlAdministratorLogin = listSecrets(resourceId(namingModule.outputs.resourceGroupFabricName, 'Microsoft.KeyVault/vaults/secrets', namingModule.outputs.keyVaultName, namingModule.outputs.postgreSqlAdministratorLoginSecretName), '2023-07-01').value
// var sqlAdministratorPassword = listSecrets(resourceId(namingModule.outputs.resourceGroupFabricName, 'Microsoft.KeyVault/vaults/secrets', namingModule.outputs.keyVaultName, namingModule.outputs.postgreSqlAdministratorPassSecretName), '2023-07-01').value

// resource secretPassword 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
//   name: '${keyVaultName}/${namingModule.outputs.postgreSqlAdministratorPassSecretName}'
//   properties: {
//     value: sqlAdministratorPassword
//   }
// }

// resource secretLogin 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
//   name: '${keyVaultName}/${namingModule.outputs.postgreSqlAdministratorLoginSecretName}'
//   properties: {
//     value: sqlAdministratorLogin
//   }
// }

module postgresqlModule 'public-postgresql.bicep' = {
  name: 'PostgreSQLDeploy'
  scope: resourceGroup()
  params: {
    postgreSqlServerName: namingModule.outputs.postgreSqlServerName
    location: location
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
    clientIpAddress: clientIpAddress
    tags: tags
  }
  dependsOn: [
  ]
}

module cosmosModule 'public-cosmosdb.bicep' = {
  name: 'CosmosDBDeploy'
  scope: resourceGroup()
  params: {
    cosmosDBName: namingModule.outputs.cosmosDBName
    location: location
    objectId: objectId
    fabricPrincipalId: fabricPrincipalId
    clientIpAddress: clientIpAddress
    tags: tags
  }
  dependsOn: [
  ]
}

output outStorageAccountName string = storageModule.outputs.outStorageAccountName
output outStorageFilesysName string = storageModule.outputs.outStorageFilesysName
output postgresqlId string = postgresqlModule.outputs.postgresqlId
output postgresqlName string = postgresqlModule.outputs.postgresqlName
output postgresqlEndpoint string = postgresqlModule.outputs.postgresqlEndpoint
output postgresqlAdminLogin string = postgresqlModule.outputs.postgresqlAdminLogin
output postgresqlVersion string = postgresqlModule.outputs.postgresqlVersion
output postgresqlStorageSizeGB int = postgresqlModule.outputs.postgresqlStorageSizeGB

output cosmosDBName string = cosmosModule.outputs.cosmosDBName
