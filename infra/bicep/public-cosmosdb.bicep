// Parameters
@description('The name of the Cosmos DB account to create.')
param cosmosDBName string

@description('Location for all resources')
param location string = resourceGroup().location

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



resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: cosmosDBName
  location: location
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

    // Firewall (IP allow list)
    ipRules: [
      {
        ipAddressOrRange: clientIpAddress
      }
    ]

    // Public access switch
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

var roleCosmosDBDataContributor = '00000000-0000-0000-0000-000000000002'

resource cosmosDBDataContributorRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-11-15-preview' = {
  name: guid(cosmos.id, objectId, roleCosmosDBDataContributor)
  parent: cosmos
  properties: {
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${roleCosmosDBDataContributor}'
    principalId: objectId
    scope: cosmos.id
  }
}

resource cosmosDBDataContributorRoleAssignmentFabric 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-11-15-preview' = {
  name: guid(cosmos.id, fabricPrincipalId, roleCosmosDBDataContributor)
  parent: cosmos
  properties: {
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${roleCosmosDBDataContributor}'
    principalId: fabricPrincipalId
    scope: cosmos.id
  }
}


// Outputs
output cosmosDBId string = cosmos.id
output cosmosDBName string = cosmos.name
output cosmosDBEndpoint string = cosmos.properties.documentEndpoint


