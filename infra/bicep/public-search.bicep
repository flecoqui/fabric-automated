// Parameters
@description('Service name must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, and is limited between 2 and 60 characters in length..')
@minLength(2)
@maxLength(60)
param searchName string

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


@description('The Fabric account principal ID.')
param fabricPrincipalId string = ''

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

@description('The tags to be applied to the provisioned resources.')
param tags object


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
  }
  tags: tags
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

var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
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

