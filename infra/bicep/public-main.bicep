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
var keyVaultName = namingModule.outputs.keyVaultName

// Fabric
var purviewAccountName = namingModule.outputs.purviewAccountName

module keyVault 'public-keyvault.bicep' = {
  name: 'keyVaultDeploy'
  scope: resourceGroup()
  params: {
    location: location
    keyVaultName: keyVaultName
    clientIpAddress: clientIpAddress
    tags: tags
  }
}

module fabric 'public-fabric.bicep' = {
  name: 'PurviewDeploy'
  scope: resourceGroup()
  params: {
    location: location
    purviewAccountName: purviewAccountName
    keyVaultName: keyVault.outputs.outKeyVaultName
    objectId: objectId
    objectType: objectType
    tags: tags
  }
}

output outKeyVaultName string = keyVault.outputs.outKeyVaultName
output outPurviewAccountName string = fabric.outputs.outPurviewAccountName
output outPurviewCatalogUri  string = fabric.outputs.outPurviewCatalogUri
output outPurviewPrincipalId string = fabric.outputs.outPurviewPrincipalId
