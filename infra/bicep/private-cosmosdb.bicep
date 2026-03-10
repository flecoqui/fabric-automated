// ── Parameters ───────────────────────────────────────────────────────────────

@description('The name of the Cosmos DB account.')
param cosmosDBName string

@description('The base name appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the virtual network.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param subnetName string

@description('Name of the resource group containing the virtual network.')
param vnetResourceGroupName string

@description('Resource ID of the private DNS zone (privatelink.documents.azure.com). Leave empty to create a new one.')
param cosmosDnsZoneId string = ''

@description('Principal ID of the Fabric / Purview managed identity for data-plane access.')
param fabricPrincipalId string = ''

@description('Object ID of the user or service principal running the deployment.')
param objectId string = ''

@description('Tags applied to all resources.')
param tags object = {}

// ── Variables ────────────────────────────────────────────────────────────────

var privateSubnetId = resourceId(vnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
var privateVnetId   = resourceId(vnetResourceGroupName, 'Microsoft.Network/virtualNetworks', vnetName)
var createDnsZone   = empty(cosmosDnsZoneId)

// Cosmos DB built-in data-plane role IDs
var roleCosmosDbDataContributor = '00000000-0000-0000-0000-000000000002'
var roleCosmosDbDataReader      = '00000000-0000-0000-0000-000000000001'

// ── Cosmos DB Account ────────────────────────────────────────────────────────

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosDBName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    // Disable public network access — all traffic via private endpoint
    publicNetworkAccess: 'Disabled'
    networkAclBypass: 'None'
    isVirtualNetworkFilterEnabled: false  // not needed with public access fully disabled
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    disableLocalAuth: false
  }
}

// ── Cosmos DB SQL Database ───────────────────────────────────────────────────

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmos
  name: 'maindb'
  properties: {
    resource: {
      id: 'maindb'
    }
    options: {
      throughput: 400
    }
  }
}

// ── Private DNS Zone ─────────────────────────────────────────────────────────

resource newCosmosDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (createDnsZone) {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: tags
}

resource vnetLinkCosmos 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (createDnsZone) {
  parent: newCosmosDnsZone
  name: '${vnetName}-link-cosmos'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: privateVnetId
    }
    registrationEnabled: false
  }
}

var resolvedDnsZoneId = createDnsZone ? newCosmosDnsZone.id : cosmosDnsZoneId

// ── Private Endpoint ─────────────────────────────────────────────────────────

resource privateEndpointCosmos 'Microsoft.Network/privateEndpoints@2024-03-01' = {
  name: 'pe-cosmos-${baseName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-cosmos-${baseName}'
        properties: {
          privateLinkServiceId: cosmos.id
          groupIds: [
            'Sql'   // sub-resource for Core (SQL) API
          ]
        }
      }
    ]
  }
}

resource dnsZoneGroupCosmos 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-03-01' = {
  parent: privateEndpointCosmos
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmos-config'
        properties: {
          privateDnsZoneId: resolvedDnsZoneId
        }
      }
    ]
  }
}

// ── Role Assignments (data-plane) ────────────────────────────────────────────
// Cosmos DB data-plane roles use sqlRoleAssignments, not ARM RBAC.
// Built-in IDs: 00..001 = Data Reader, 00..002 = Data Contributor

resource roleAssignmentUser 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = if (!empty(objectId)) {
  name: guid(cosmos.id, objectId, roleCosmosDbDataContributor)
  parent: cosmos
  properties: {
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${roleCosmosDbDataContributor}'
    principalId: objectId
    scope: cosmos.id   // can be narrowed to a specific database or container
  }
}

resource roleAssignmentFabricReader 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = if (!empty(fabricPrincipalId)) {
  name: guid(cosmos.id, fabricPrincipalId, roleCosmosDbDataReader)
  parent: cosmos
  properties: {
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${roleCosmosDbDataReader}'
    principalId: fabricPrincipalId
    scope: cosmos.id
  }
}

// ── Outputs ──────────────────────────────────────────────────────────────────

output cosmosDBId       string = cosmos.id
output cosmosDBName     string = cosmos.name
output cosmosEndpoint   string = cosmos.properties.documentEndpoint
output databaseName     string = cosmosDatabase.name
output privateEndpointId string = privateEndpointCosmos.id
output dnsZoneId        string = resolvedDnsZoneId
