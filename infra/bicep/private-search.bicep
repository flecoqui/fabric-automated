// Parameters
@description('Service name must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, and is limited between 2 and 60 characters in length..')
@minLength(2)
@maxLength(60)
param searchName string

@description('The base name appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('Location for all resources')
param location string = resourceGroup().location

@allowed([
  'free'
  'basic'
  'standard'
  'standard2'
  'standard3'
  'storage_optimized_l1'
  'storage_optimized_l2'
])
@description('The pricing tier of the search service you want to create (for example, basic or standard).')
param sku string = 'standard'

@description('Replicas distribute search workloads across the service. You need at least two replicas to support high availability of query workloads (not applicable to the free tier).')
@minValue(1)
@maxValue(12)
param replicaCount int = 1

@description('Partitions allow for scaling of document count as well as faster indexing by sharding your index over multiple search units.')
@allowed([
  1
  2
  3
  4
  6
  12
])
param partitionCount int = 1

@description('Applicable only for SKUs set to standard3. You can set this property to enable a single, high density partition that allows up to 1000 indexes, which is much higher than the maximum indexes allowed for any other SKU.')
@allowed([
  'default'
  'highDensity'
])
param hostingMode string = 'default'


@description('Name for the Private DNS Zone (Azure AI Search uses privatelink.search.windows.net)')
param privateDnsZoneName string = 'privatelink.search.windows.net'


@description('The name of the virtual network for virtual network integration.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param subnetName string

@description('The name of the resource group containing the virtual network.')
param vnetResourceGroupName  string

@description('Resource ID of the private DNS zone (privatelink.search.windows.net). Leave empty to create a new one.')
param searchPrivateDnsZoneId string = ''

@description('The Fabric account principal ID.')
param fabricPrincipalId string = ''

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

@description('The tags to be applied to the provisioned resources.')
param tags object

var privateSubnetId = resourceId(vnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
var privateVnetId   = resourceId(vnetResourceGroupName, 'Microsoft.Network/virtualNetworks', vnetName)
var createDnsZone   = empty(searchPrivateDnsZoneId)
  
resource search 'Microsoft.Search/searchServices@2020-08-01' = {
  name: searchName
  location: location
  sku: {
    name: sku
  }
  properties: {
    replicaCount: replicaCount
    partitionCount: partitionCount
    hostingMode: hostingMode
    publicNetworkAccess: 'disabled'    
  }
  tags: tags
}


//
// 2) Private DNS Zone for Azure AI Search Private Link
//
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (createDnsZone){
  name: 'privatelink.search.windows.net'
  location: 'global'
  tags: tags
  properties: {}
}

//
// 3) Link DNS zone to your VNet (so VMs/clients in VNet resolve *.search.windows.net privately)
//
resource dnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createDnsZone){
  name: '${vnetName}-link-search'
  parent: privateDnsZone
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: privateVnetId
    }
  }
}

//
// 4) Private Endpoint pointing to the Search service
//
resource privateEndpointSearch 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: 'pe-search-${baseName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-search-${baseName}'
        properties: {
          privateLinkServiceId: search.id

          // groupIds is required for Private Link; the PE resource supports groupIds in the schema
          // (For Search, this is commonly "searchService")
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
}

//
// 5) Attach the Private DNS zone to the Private Endpoint via a DNS Zone Group
//
resource peDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = {
  name: 'default'
  parent: privateEndpointSearch
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

var searchContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
resource storageFileRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, fabricPrincipalId, searchContributorRoleId)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchContributorRoleId)
    principalId: fabricPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobRoleAssignment2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, objectId, searchContributorRoleId)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchContributorRoleId)
    principalId: objectId
    principalType: objectType
  }
}

var searchIndexDataContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
resource storageFileRoleAssignment3 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, fabricPrincipalId, searchIndexDataContributorRoleId)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: fabricPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobRoleAssignment4 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, objectId, searchIndexDataContributorRoleId)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: objectId
    principalType: objectType
  }
}


// Outputs
output searchId string = search.id
output searchName string = search.name
output searchEndpoint string = 'https://${searchName}.search.windows.net'


