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

@description('The name of the Azure resource group containing the Azure Private DNS Zones used for registering private endpoints.')
param dnsZoneResourceGroupName string = resourceGroup().name

@description('The ID of the Azure subscription containing the Azure Private DNS Zones used for registering private endpoints.')
param dnsZoneSubscriptionId string = subscription().subscriptionId

@description('Indicator if new Azure Private DNS Zones should be created, or using existing Azure Private DNS Zones.')
@allowed([
  'new'
  'existing'
])
param newOrExistingDnsZones string = 'existing'

@description('The Sql administrator login of the administrator account.')
param sqlAdministratorLogin string

@description('The Sql administrator password of the administrator account.')
@secure()
param sqlAdministratorPassword string

@description('The Fabric account principal ID.')
param purviewPrincipalId string = ''

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
// Networking related variables
var vnetName =  namingModule.outputs.vnetName
var privateEndpointSubnetName = namingModule.outputs.privateEndpointSubnetName
// Azure Storage account related variables
var storageAccountName = namingModule.outputs.storageAccountName
var containerName = namingModule.outputs.storageAccountDefaultContainerName

// Defining Private DNS Zones resource group and subscription id
var calcDnsZoneResourceGroupName = (newOrExistingDnsZones == 'new') ? resourceGroup().name : dnsZoneResourceGroupName
var calcDnsZoneSubscriptionId = (newOrExistingDnsZones == 'new') ? subscription().subscriptionId : dnsZoneSubscriptionId

// Getting the Ids for existing or newly created Private DNS Zones
var dfsPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.dfs.${environment().suffixes.storage}')
var blobPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${environment().suffixes.storage}')
///subscriptions/4b6e25b6-6b90-497a-9aa7-e673e32bc08c/resourceGroups/rgprivatepurview/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net
//var dfsPrivateDnsZoneId = resourceId('4b6e25b6-6b90-497a-9aa7-e673e32bc08c', 'rgprivatepurview', 'Microsoft.Network/privateDnsZones', 'privatelink.blob.core.windows.net')


///subscriptions/4b6e25b6-6b90-497a-9aa7-e673e32bc08c/resourceGroups/rgprivatepurview/providers/Microsoft.Network/privateDnsZones/privatelink.dfs.core.windows.net
//var blobPrivateDnsZoneId = resourceId('4b6e25b6-6b90-497a-9aa7-e673e32bc08c', 'rgprivatepurview', 'Microsoft.Network/privateDnsZones', 'privatelink.dfs.core.windows.net')




module storage 'private-storage.bicep' = {
  name: 'StorageDeploy'
  scope: resourceGroup()
  params: {
    location: location
    baseName: namingModule.outputs.baseName
    storageAccountName: storageAccountName
    defaultContainerName: containerName
    vnetName: vnetName
    subnetName: privateEndpointSubnetName
    vnetResourceGroupName: dnsZoneResourceGroupName
    dfsPrivateDnsZoneId: dfsPrivateDnsZoneId
    blobPrivateDnsZoneId: blobPrivateDnsZoneId
    purviewPrincipalId: purviewPrincipalId
    objectId: objectId
    objectType: objectType
    clientIpAddress: clientIpAddress
    tags: tags
  }
}

module synapse 'private-synapse-workspace.bicep' = {
  name: 'SynapseDeploy'
  scope: resourceGroup()
  params: {
    workspaceName: namingModule.outputs.synapseWorkspaceName
    location: location
    baseName: namingModule.outputs.baseName
    defaultStorageAccountName: namingModule.outputs.synapseStorageAccountName
    defaultFileSystemName: namingModule.outputs.synapseFileSystemName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlPoolName: namingModule.outputs.synapseSqlPoolName
    sqlPoolSku: namingModule.outputs.synapseSqlPoolSku
    sparkPoolName: namingModule.outputs.synapseSparkPoolName
    sparkPoolNodeSize: namingModule.outputs.synapseSparkPoolNodeSize
    sparkPoolMinNodeCount: namingModule.outputs.synapseSparkPoolMinNodeCount
    sparkPoolMaxNodeCount: namingModule.outputs.synapseSparkPoolMaxNodeCount
    sparkPoolAutoScaleEnabled: namingModule.outputs.synapseSparkPoolAutoScaleEnabled
    sparkPoolAutoPauseEnabled: namingModule.outputs.synapseSparkPoolAutoPauseEnabled
    sparkPoolAutoPauseDelayInMinutes: namingModule.outputs.synapseSparkPoolAutoPauseDelayInMinutes
    sparkVersion: namingModule.outputs.synapseSparkVersion

    vnetName: vnetName
    subnetName: privateEndpointSubnetName
    vnetResourceGroupName: dnsZoneResourceGroupName
    dfsPrivateDnsZoneId: dfsPrivateDnsZoneId
    blobPrivateDnsZoneId: blobPrivateDnsZoneId
    purviewPrincipalId: purviewPrincipalId
    objectId: objectId
    objectType: objectType
    clientIpAddress: clientIpAddress
    tags: tags
  }
  dependsOn: [
  ]
}

output outStorageAccountName string = storage.outputs.outStorageAccountName
output outStorageFilesysName string = storage.outputs.outStorageFilesysName
