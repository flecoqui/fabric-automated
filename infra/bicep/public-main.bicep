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

@description('The principal name of the user or service principal running the script.')
param principalName string = ''

@description('The fabric sku.')
@allowed([
  'F2'
  'F4'
  'F8'
  'F16'
  'F32'
  'F64'
  'F128'
  'F256'
  'F512'
  'F1024'
  'F2048'
])
param fabricSKU string = 'F2'


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
var fabricAccountName = namingModule.outputs.fabricAccountName

module keyVaultModule 'public-keyvault.bicep' = {
  name: 'keyVaultDeploy'
  scope: resourceGroup()
  params: {
    location: location
    keyVaultName: keyVaultName
    clientIpAddress: clientIpAddress
    objectId: objectId
    objectType: objectType
    tags: tags
  }
}

module fabricModule 'public-fabric.bicep' = {
  name: 'FabricDeploy'
  scope: resourceGroup()
  params: {
    location: location
    fabricAccountName: fabricAccountName
    fabricSku: fabricSKU
    fabricAdminId: principalName
    tags: tags
  }
}

output outKeyVaultName string = keyVaultModule.outputs.outKeyVaultName
output outFabricAccountName string = fabricModule.outputs.outFabricAccountName

