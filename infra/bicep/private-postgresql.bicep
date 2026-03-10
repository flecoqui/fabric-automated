// Parameters
// Parameters
@description('The name of the PostgreSQL server')
param postgreSqlServerName string

@description('The base name to be appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('The SQL administrator login username')
param sqlAdministratorLogin string

@description('The SQL administrator login password')
@secure()
param sqlAdministratorPassword string

@description('The SKU name for the dedicated SQL server')
@allowed([
  'Standard_D2ds_v4'
  'Standard_D4ds_v4'
])
param sqlInstanceName string = 'Standard_D2ds_v4'

@description('The sql version for the dedicated SQL server')
@allowed([
  '11'
  '12'
  '13'
  '14'
  '15'
  '16'
  '17'
  '18'
])
param sqlVersion string = '13'

@description('The name of the virtual network for virtual network integration.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param subnetName string

@description('The name of the resource group containing the virtual network.')
param vnetResourceGroupName  string

@description('Resource ID of the private DNS zone for PostgreSQL (privatelink.postgres.database.azure.com). Pass empty string to create a new one.')
param postgresDnsZoneId string = ''

@description('The tags to be applied to the provisioned resources.')
param tags object = {}


// Variables
var privateSubnetId = resourceId(vnetResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
var privateVnetId   = resourceId(vnetResourceGroupName, 'Microsoft.Network/virtualNetworks', vnetName)
var createDnsZone   = empty(postgresDnsZoneId)

#disable-next-line BCP081
resource postgresql 'Microsoft.DBforPostgreSQL/flexibleServers@2026-01-01-preview' = {
  name: postgreSqlServerName
  location: location
  sku: {
    name: sqlInstanceName
    tier: 'GeneralPurpose'
  }
  properties: {
    version: sqlVersion
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    network: {
      publicNetworkAccess: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
  tags: tags
}

// ── Private DNS Zone ─────────────────────────────────────────────────────────
resource newPostgresDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (createDnsZone) {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

resource vnetLinkPostgres 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (createDnsZone) {
  parent: newPostgresDnsZone
  name: '${vnetName}-link-postgres'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: privateVnetId
    }
    registrationEnabled: false
  }
}

// Resolve the effective DNS zone ID (new or existing)
var resolvedDnsZoneId = createDnsZone ? newPostgresDnsZone.id : postgresDnsZoneId

// ── Private Endpoint ─────────────────────────────────────────────────────────
resource privateEndpointPostgres 'Microsoft.Network/privateEndpoints@2024-03-01' = {
  name: 'pe-pg-${baseName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-pg-${baseName}'
        properties: {
          privateLinkServiceId: postgresql.id
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
  }
}

resource dnsZoneGroupPostgres 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-03-01' = {
  parent: privateEndpointPostgres
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'postgres-config'
        properties: {
          privateDnsZoneId: resolvedDnsZoneId
        }
      }
    ]
  }
}


// ── Outputs ──────────────────────────────────────────────────────────────────
output postgreSqlServerId   string = postgresql.id
output postgreSqlServerName string = postgresql.name
output postgreSqlFqdn       string = postgresql.properties.fullyQualifiedDomainName
output privateEndpointId    string = privateEndpointPostgres.id
output dnsZoneId            string = resolvedDnsZoneId
