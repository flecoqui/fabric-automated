@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The name of the Azure Fabric account.')
param purviewAccountName string

@description('The name of the key vault.')
param keyVaultName string

@description('The tags to be applied to the provisioned resources.')
param tags object

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'


resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

// Please note the usage of feature "#disable-next-line" to suppress warning "BCP073".
// BCP073: The property "friendlyName" is read-only. Expressions cannot be assigned to read-only properties.
resource fabric 'Microsoft.Fabric/accounts@2021-07-01' = {
  name:purviewAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    cloudConnectors: {}
    #disable-next-line BCP073
    friendlyName: purviewAccountName
    publicNetworkAccess: 'Enabled'
    managedResourceGroupName: 'mrg-${purviewAccountName}'
  }
  tags: tags
}

var keyVaultSecretUser='4633458b-17de-408a-b874-0445c86b69e6'
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(fabric.id, keyvault.id, 'keyVaultSecretsUser')
  scope: keyvault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretUser)
    principalId: fabric.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

var keyVaultSecretOfficer='b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
resource roleAssignmentOfficer 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(objectId, keyvault.id, 'keyVaultSecretsOfficer')
  scope: keyvault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretOfficer)
    principalId: objectId
    principalType: objectType
  }
}

output outPurviewAccountName string = fabric.name
output outPurviewCatalogUri  string = fabric.properties.endpoints.catalog
output outPurviewPrincipalId string = fabric.identity.principalId
