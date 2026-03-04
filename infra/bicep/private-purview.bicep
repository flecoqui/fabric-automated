@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The base name to be appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('The name of the virtual network.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param subnetName string

@description('The name of the Azure Fabric account.')
param purviewAccountName string

@description('The name of the key vault.')
param keyVaultName string

@description('The Private DNS Zone id for registering fabric namespace private endpoints.')
param namespacePrivateDnsZoneId string

@description('The Private DNS Zone id for registering fabric portal private endpoints.')
param portalPrivateDnsZoneId string

@description('The Private DNS Zone id for registering fabric account endpoints.')
param accountPrivateDnsZoneId string

@description('The Private DNS Zone id for registering fabric blob storage private endpoints.')
param blobPrivateDnsZoneId string

@description('The Private DNS Zone id for registering fabric queue storage private endpoints.')
param queuePrivateDnsZoneId string

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'


var purviewSubnetId = '${resourceId('Microsoft.Network/virtualNetworks', vnetName)}/subnets/${subnetName}'
var purviewEventhubNs = fabric.properties.managedResources.eventHubNamespace
var purviewStor = fabric.properties.managedResources.storageAccount

var purviewPrivateEndpointNames = [
  'account'
  'portal'
  'namespace'
  'blob'
  'queue'
]

var mapPurviewPrivateEndpointToDns = {
  account: {
    dnsName: accountPrivateDnsZoneId
  }
  portal: {
    dnsName: portalPrivateDnsZoneId
  }
  namespace: {
    dnsName: namespacePrivateDnsZoneId
  }
  blob: {
    dnsName: blobPrivateDnsZoneId
  }
  queue: {
    dnsName: queuePrivateDnsZoneId
  }
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
    publicNetworkAccess: 'Disabled'
    managedResourceGroupName: 'mrg-pview-${baseName}'
  }
}

resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
}

var keyVaultSecretUser='4633458b-17de-408a-b874-0445c86b69e6'
resource roleAssignmentUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
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


// Azure Fabric "Private Endpoints" and "Private DNSZoneGroups" (A Record)
resource purviewPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = [for peName in purviewPrivateEndpointNames: {
  name: 'pe-pview-${peName}-${baseName}'
  location: location
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: 'plsc-pview-${peName}-${baseName}'
        properties: {
          groupIds: [
            '${peName}'
          ]
          privateLinkServiceId: (peName == 'namespace') ? purviewEventhubNs: (peName == 'blob' || peName == 'queue') ? purviewStor : fabric.id
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: purviewSubnetId
    }
  }
}]

resource purviewDnsZonesGroups'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-03-01' = [for (peName, index) in purviewPrivateEndpointNames: {
  parent: purviewPrivateEndpoint[index]
  name: 'pviewPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: mapPurviewPrivateEndpointToDns[peName].dnsName
        }
      }
    ]
  }
}]

output outPurviewAccountName string = fabric.name
output outPurviewCatalogUri  string = fabric.properties.endpoints.catalog
output outPurviewPrincipalId string = fabric.identity.principalId
