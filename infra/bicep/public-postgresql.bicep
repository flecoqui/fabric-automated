// Parameters
@description('The name of the PostgreSQL server')
param postgreSqlServerName string

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

@description('The client IP address.')
param clientIpAddress string = ''

@description('The tags to be applied to the provisioned resources.')
param tags object


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
      publicNetworkAccess: 'Enabled'
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

resource postgresFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2025-06-01-preview' = {
  parent: postgresql
  name: 'allow-client-ip'
  properties: {
    startIpAddress: clientIpAddress
    endIpAddress: clientIpAddress
  }
}


// Outputs
output postgresqlId string = postgresql.id
output postgresqlName string = postgresql.name
output postgresqlEndpoint string = postgresql.properties.fullyQualifiedDomainName
output postgresqlAdminLogin string = postgresql.properties.administratorLogin
output postgresqlVersion string = postgresql.properties.version
output postgresqlStorageSizeGB int = postgresql.properties.storage.storageSizeGB
