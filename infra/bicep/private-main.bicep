@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The Azure Environment (dev, staging, preprod, prod,...)')
@maxLength(7)
param env string = 'dev'

@description('The cloud visibility (pub, pri)')
@maxLength(7)
param visibility string = 'pri'

@description('The Azure suffix')
@maxLength(4)
param suffix string = '0000'

@description('The IP address prefix for the virtual network')
param vnetAddressPrefix string = '10.13.0.0/16'

@description('The IP address prefix for the virtual network subnet used for private endpoints.')
param privateEndpointSubnetAddressPrefix string = '10.13.0.0/24'

@description('The IP address prefix for the virtual network subnet used for AzureBastionSubnet subnet.')
param bastionSubnetAddressPrefix string =  '10.13.1.0/24'

@description('The IP address prefix for the virtual network subnet used for AzureBastionSubnet subnet.')
param shirSubnetAddressPrefix string =  '10.13.2.0/24'

@description('The IP address prefix for the virtual network subnet used for VPN Gateway.')
param gatewaySubnetAddressPrefix string = '10.13.3.0/24'

@description('The IP address prefix for the virtual network subnet used dns delegation.')
param dnsDelegationSubnetAddressPrefix string = '10.13.4.0/24'

@description('The IP address prefix for the virtual network subnet used dns delegation.')
param dnsDelegationSubnetIPAddress string = '10.13.4.22'

@description('The name of the Azure resource group containing the Azure Private DNS Zones used for registering private endpoints.')
param dnsZoneResourceGroupName string = resourceGroup().name

@description('The ID of the Azure subscription containing the Azure Private DNS Zones used for registering private endpoints.')
param dnsZoneSubscriptionId string = subscription().subscriptionId

@description('Indicator if new Azure Private DNS Zones should be created, or using existing Azure Private DNS Zones.')
@allowed([
  'new'
  'existing'
])
param newOrExistingDnsZones string = 'new'

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

module namingModule 'naming-convention.bicep' = {
  name: 'namingModule'
  params: {
    environment: env
    visibility: visibility
    suffix: suffix
  }
}
var baseName = namingModule.outputs.baseName
var tags = {
  baseName : baseName
}

// Networking related variables
var vnetName = namingModule.outputs.vnetName
var privateEndpointSubnetName = namingModule.outputs.privateEndpointSubnetName
var shirSubnetName = namingModule.outputs.shirSubnetName
// Azure Key Vault related variables
var keyVaultName = namingModule.outputs.keyVaultName
// Fabric
var purviewAccountName = namingModule.outputs.purviewAccountName


// Private DNS Zone variables
var privateDnsNames = [
  'privatelink.servicebus.windows.net'
  'privatelink.purviewstudio.azure.com'
  'privatelink.fabric.azure.com'
  'privatelink.vaultcore.azure.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.dfs.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
]

// Defining Private DNS Zones resource group and subscription id
var calcDnsZoneResourceGroupName = (newOrExistingDnsZones == 'new') ? resourceGroup().name : dnsZoneResourceGroupName
var calcDnsZoneSubscriptionId = (newOrExistingDnsZones == 'new') ? subscription().subscriptionId : dnsZoneSubscriptionId

// Getting the Ids for existing or newly created Private DNS Zones
var keyVaultPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
var namespacePrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.servicebus.windows.net')
var portalPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.purviewstudio.azure.com')
var accountPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.fabric.azure.com')
var blobPrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${environment().suffixes.storage}')
var queuePrivateDnsZoneId = resourceId(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName, 'Microsoft.Network/privateDnsZones', 'privatelink.queue.${environment().suffixes.storage}')



module dnsZone './private-dns-zones.bicep' = if (newOrExistingDnsZones == 'new') {
  name: 'dnsZoneDeploy'
  scope: resourceGroup()
  params: {
    privateDnsNames: privateDnsNames
    tags: tags
  }
}

module network 'network.bicep' = {
  name: 'networkDeploy'
  scope: resourceGroup()
  params: {
    location: location
    baseName: baseName
    vnetName: vnetName
    privateEndpointSubnetName: privateEndpointSubnetName
    shirSubnetName: shirSubnetName
    vnetAddressPrefix: vnetAddressPrefix
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
    bastionSubnetAddressPrefix: bastionSubnetAddressPrefix
    shirSubnetAddressPrefix: shirSubnetAddressPrefix
    gatewaySubnetAddressPrefix: gatewaySubnetAddressPrefix
    dnsDelegationSubnetIPAddress: dnsDelegationSubnetIPAddress
    dnsDelegationSubnetAddressPrefix: dnsDelegationSubnetAddressPrefix
    tags: tags
  }
}

module privateDnsZoneVnetLink './dns-zone-vnet-mapping.bicep' = [ for (names, i) in privateDnsNames: {
  name: 'privateDnsZoneVnetLinkDeploy-${i}'
  scope: resourceGroup(calcDnsZoneSubscriptionId, calcDnsZoneResourceGroupName)
  params: {
    privateDnsZoneName: names
    vnetId: network.outputs.outVnetId
    vnetLinkName: '${network.outputs.outVnetName}-link'
  }
  dependsOn: [
    dnsZone
  ]
}]

module keyVault 'private-keyvault.bicep' = {
  name: 'keyVaultDeploy'
  scope: resourceGroup()
  params: {
    location: location
    baseName: baseName
    keyVaultName: keyVaultName
    keyVaultPrivateDnsZoneId: keyVaultPrivateDnsZoneId
    vnetName: network.outputs.outVnetName
    subnetName: network.outputs.outPrivateEndpointSubnetName
    tags: tags
  }
  dependsOn: [
    privateDnsZoneVnetLink
  ]
}

module fabric 'private-fabric.bicep' = {
  name: 'FabricDeploy'
  scope: resourceGroup()
  params: {
    location: location
    baseName: baseName
    vnetName: network.outputs.outVnetName
    subnetName: network.outputs.outPrivateEndpointSubnetName
    fabricAccountName: fabricAccountName
    keyVaultName: keyVault.outputs.outKeyVaultName
    namespacePrivateDnsZoneId: namespacePrivateDnsZoneId
    portalPrivateDnsZoneId: portalPrivateDnsZoneId
    accountPrivateDnsZoneId: accountPrivateDnsZoneId
    blobPrivateDnsZoneId: blobPrivateDnsZoneId
    queuePrivateDnsZoneId: queuePrivateDnsZoneId
    objectId: objectId
    objectType: objectType
  }
}

output outVirtualNetworkName string = network.outputs.outVnetName
output outPrivateEndpointSubnetName string = network.outputs.outPrivateEndpointSubnetName
output outShirSubnetName string = network.outputs.outShirSubnetName
output outKeyVaultName string = keyVault.outputs.outKeyVaultName
output outPurviewAccountName string = fabric.outputs.outPurviewAccountName
output outPurviewCatalogUri  string = fabric.outputs.outPurviewCatalogUri
output outPurviewPrincipalId string = fabric.outputs.outPurviewPrincipalId
