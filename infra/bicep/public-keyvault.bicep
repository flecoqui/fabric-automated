@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('Name of the key vault resource.')
param keyVaultName string

@description('The client IP address.')
param clientIpAddress string = ''

@description('The tags to be applied to the provisioned resources.')
param tags object


resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [{
          value: clientIpAddress
        }]
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'enabled'
  }
}

output outKeyVaultName string = keyVault.name
