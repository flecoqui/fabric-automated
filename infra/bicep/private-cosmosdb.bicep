// Parameters
@description('The name of the Synapse workspace')
param workspaceName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('The base name to be appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('The name of the default storage account for Synapse')
param defaultStorageAccountName string

@description('The name of the default file system (container) in the storage account')
param defaultFileSystemName string = 'synapsefs'

@description('The SQL administrator login username')
param sqlAdministratorLogin string

@description('The SQL administrator login password')
@secure()
param sqlAdministratorPassword string

@description('The name of the dedicated SQL pool')
param sqlPoolName string = 'dedicatedSqlPool'

@description('The SKU name for the dedicated SQL pool')
@allowed([
  'DW100c'
  'DW200c'
  'DW300c'
  'DW400c'
  'DW500c'
  'DW1000c'
  'DW1500c'
  'DW2000c'
  'DW2500c'
  'DW3000c'
])
param sqlPoolSku string = 'DW100c'

@description('The name of the Apache Spark pool')
param sparkPoolName string = 'sparkPool'

@description('The node size for the Spark pool')
@allowed([
  'Small'
  'Medium'
  'Large'
  'XLarge'
  'XXLarge'
])
param sparkPoolNodeSize string = 'Small'

@description('The minimum number of nodes for the Spark pool')
@minValue(3)
param sparkPoolMinNodeCount int = 3

@description('The maximum number of nodes for the Spark pool')
@minValue(3)
param sparkPoolMaxNodeCount int = 10

@description('Enable auto-scale for the Spark pool')
param sparkPoolAutoScaleEnabled bool = true

@description('Enable auto-pause for the Spark pool')
param sparkPoolAutoPauseEnabled bool = true

@description('Auto-pause delay in minutes')
param sparkPoolAutoPauseDelayInMinutes int = 15

@description('Apache Spark version')
@allowed([
  '2.4'
  '3.1'
  '3.2'
  '3.3'
  '3.4'
])
param sparkVersion string = '3.3'

@description('The name of the virtual network for virtual network integration.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param subnetName string

@description('The name of the resource group containing the virtual network.')
param vnetResourceGroupName  string

@description('The Private DNS Zone id for registering storage "dfs" private endpoints.')
param dfsPrivateDnsZoneId string

@description('The Private DNS Zone id for registering storage "blob" private endpoints.')
param blobPrivateDnsZoneId string

@description('The Fabric account principal ID.')
param purviewPrincipalId string = ''

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

@description('The client IP address.')
param clientIpAddress string = ''

@description('The tags to be applied to the provisioned resources.')
param tags object

// Variables
var roleStorageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var roleStorageBlobDataReader='2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
// var roleStorageFileContributor='69566ab7-960f-475b-8e7c-b3118f30c6bd'
var roleStorageFileReader='b8eda974-7b85-4f76-af95-65846b26df6d'
var roleSynapseReader='acdd72a7-3385-48ef-bd42-f606fba81ae7'

var privateVnetId = resourceId(vnetResourceGroupName,'Microsoft.Network/virtualNetworks', vnetName)
var privateSubnetId = '${resourceId(vnetResourceGroupName,'Microsoft.Network/virtualNetworks', vnetName)}/subnets/${subnetName}'

// Storage Account for Synapse default storage
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: defaultStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true // Enable hierarchical namespace (Data Lake Gen2)
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: clientIpAddress
          action: 'Allow'
        }
      ]
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// Blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Default file system (container) for Synapse
resource fileSystem 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: defaultFileSystemName
  properties: {
    publicAccess: 'None'
  }
}

// Azure Storage Account "Private Endpoints" and "Private DNSZoneGroups" (A Record)
resource privateEndpointBlob 'Microsoft.Network/privateEndpoints@2024-03-01' = {
  name: 'pe-sy-st-blob-${baseName}'
  location: location
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-sy-st-blob-${baseName}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}


resource dnsZonesGroupsBlob 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-03-01' = {
  parent: privateEndpointBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storage-blob-config'
        properties: {
          privateDnsZoneId: blobPrivateDnsZoneId
        }
      }
    ]
  }
}


resource privateEndpointDfs 'Microsoft.Network/privateEndpoints@2024-03-01' = {
  name: 'pe-sy-st-dfs-${baseName}'
  location: location
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-sy-st-dfs-${baseName}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'dfs'
          ]
        }
      }
    ]
  }
}


resource dnsZonesGroupsDfs 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-03-01' = {
  parent: privateEndpointDfs
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storage-dfs-config'
        properties: {
          privateDnsZoneId: dfsPrivateDnsZoneId
        }
      }
    ]
  }
}


// Synapse Workspace
resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: storageAccount.properties.primaryEndpoints.dfs
      filesystem: defaultFileSystemName
      resourceId: storageAccount.id
      createManagedPrivateEndpoint: true
    }
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorPassword

    managedResourceGroupName: 'rg-synapse-managed-${baseName}'
    publicNetworkAccess: 'Disabled'
    managedVirtualNetwork: 'default'
    managedVirtualNetworkSettings: {
      preventDataExfiltration: true
      allowedAadTenantIdsForLinking: []
    }
    azureADOnlyAuthentication: false
    trustedServiceBypassEnabled: true
  }
  dependsOn: [
    fileSystem
  ]
}

// Private DNS Zones
resource privateDnsZoneSynapseDev 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.dev.azuresynapse.net'
  location: 'global'
  tags: tags
}

resource privateDnsZoneSynapseSql 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.sql.azuresynapse.net'
  location: 'global'
  tags: tags
}

// VNet Links for Private DNS Zones
resource vnetLinkSynapseDev 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZoneSynapseDev
  name: '${vnetName}-link-dev'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: privateVnetId
    }
    registrationEnabled: false
  }
}

resource vnetLinkSynapseSql 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZoneSynapseSql
  name: '${vnetName}-link-sql'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: privateVnetId
    }
    registrationEnabled: false
  }
}

// Private Endpoint for Synapse Workspace (Dev)
resource privateEndpointSynapseDev 'Microsoft.Network/privateEndpoints@2024-03-01' = {
  name: 'pe-sy-dev-${baseName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-sy-dev-${baseName}'
        properties: {
          privateLinkServiceId: synapseWorkspace.id
          groupIds: [
            'Dev'
          ]
        }
      }
    ]
  }
}

// Private Endpoint for Synapse Workspace (SQL)
resource privateEndpointSynapseSql 'Microsoft.Network/privateEndpoints@2024-03-01' = {
  name: 'pe-sy-sql-${baseName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-sy-sql-${baseName}'
        properties: {
          privateLinkServiceId: synapseWorkspace.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
}

// Private Endpoint for Synapse Workspace (SQL On Demand)
resource privateEndpointSynapseSqlOnDemand 'Microsoft.Network/privateEndpoints@2024-03-01' = {
  name: 'pe-sy-sqlod-${baseName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-sy-sqlod-${baseName}'
        properties: {
          privateLinkServiceId: synapseWorkspace.id
          groupIds: [
            'SqlOnDemand'
          ]
        }
      }
    ]
  }
}

// DNS Zone Groups for Private Endpoints
resource dnsZoneGroupSynapseDev 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-03-01' = {
  parent: privateEndpointSynapseDev
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'synapse-dev-config'
        properties: {
          privateDnsZoneId: privateDnsZoneSynapseDev.id
        }
      }
    ]
  }
}

resource dnsZoneGroupSynapseSql 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-03-01' = {
  parent: privateEndpointSynapseSql
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'synapse-sql-config'
        properties: {
          privateDnsZoneId: privateDnsZoneSynapseSql.id
        }
      }
    ]
  }
}

resource dnsZoneGroupSynapseSqlOnDemand 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-03-01' = {
  parent: privateEndpointSynapseSqlOnDemand
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'synapse-sqlod-config'
        properties: {
          privateDnsZoneId: privateDnsZoneSynapseSql.id
        }
      }
    ]
  }
}

// Grant Synapse workspace managed identity Storage Blob Data Contributor role on the storage account
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, synapseWorkspace.id, roleStorageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataContributor)
    principalId: synapseWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Dedicated SQL Pool
resource sqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  parent: synapseWorkspace
  name: sqlPoolName
  location: location
  tags: tags
  sku: {
    name: sqlPoolSku
  }
  properties: {
    createMode: 'Default'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

// Apache Spark Pool
resource sparkPool 'Microsoft.Synapse/workspaces/bigDataPools@2021-06-01' = {
  parent: synapseWorkspace
  name: sparkPoolName
  location: location
  tags: tags
  properties: {
    nodeCount: sparkPoolAutoScaleEnabled ? 0 : sparkPoolMinNodeCount
    nodeSizeFamily: 'MemoryOptimized'
    nodeSize: sparkPoolNodeSize
    autoScale: {
      enabled: sparkPoolAutoScaleEnabled
      minNodeCount: sparkPoolMinNodeCount
      maxNodeCount: sparkPoolMaxNodeCount
    }
    autoPause: {
      enabled: sparkPoolAutoPauseEnabled
      delayInMinutes: sparkPoolAutoPauseDelayInMinutes
    }
    sparkVersion: sparkVersion
    dynamicExecutorAllocation: {
      enabled: true
      minExecutors: 1
      maxExecutors: sparkPoolMaxNodeCount-1
    }
    isComputeIsolationEnabled: false
    sessionLevelPackagesEnabled: true
    cacheSize: 0
  }
}

resource storageBlobRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, purviewPrincipalId, roleStorageBlobDataReader)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataReader)
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageFileRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, purviewPrincipalId, roleStorageFileReader)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageFileReader)
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageBlobRoleAssignment2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, objectId, roleStorageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleStorageBlobDataContributor)
    principalId: objectId
    principalType: objectType
  }
}

resource synapseReaderRoleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(synapseWorkspace.id, purviewPrincipalId, roleSynapseReader)
  scope: synapseWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSynapseReader)
    principalId: purviewPrincipalId
    principalType: 'ServicePrincipal'
  }
}


// NOTE: Deployment scripts cannot connect to Synapse with publicNetworkAccess: 'Disabled'
// Consider using Azure DevOps pipeline, GitHub Actions, or a VM with private network access
// to run SQL scripts against private Synapse workspaces.
//
// If you need to run SQL scripts, here's a corrected template (commented out):
/*
resource sqlDeploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-sql-deployment-${baseName}'
  location: location
  tags: tags
}

resource sqlDeployment 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'runSqlScript-${baseName}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${sqlDeploymentIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.52.0'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'SQL_SERVER'
        value: '${workspaceName}.sql.azuresynapse.net'
      }
      {
        name: 'SQL_DATABASE'
        value: sqlPoolName
      }
      {
        name: 'SQL_USER'
        value: sqlAdministratorLogin
      }
      {
        name: 'SQL_PASSWORD'
        secureValue: sqlAdministratorPassword
      }
    ]
    scriptContent: '''
      # Install sqlcmd
      curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
      curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
      apt-get update
      ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev

      # Run SQL commands
      /opt/mssql-tools/bin/sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -d "$SQL_DATABASE" -Q "
        -- Your SQL commands here
        SET ANSI_NULLS ON
        GO
        SET QUOTED_IDENTIFIER ON
        GO
        CREATE TABLE [dbo].[Product](
            [ProductKey] [nvarchar](50) NOT NULL,
            [ProductName] [nvarchar](50) NULL,
            [Category][nvarchar](50) NULL,
            [ListPrice] [nvarchar](50) NULL)
        WITH
        (
          DISTRIBUTION = HASH(ProductKey),
          CLUSTERED COLUMNSTORE INDEX
        );
        GO

        INSERT Product
        VALUES('786','Mountain-300 Black','Mountain Bikes','2294.9900');
        GO

      "
    '''
  }
  dependsOn: [
    sqlPool
  ]
}
*/



// Outputs
output synapseWorkspaceId string = synapseWorkspace.id
output synapseWorkspaceName string = synapseWorkspace.name
output synapseWorkspaceEndpoint string = synapseWorkspace.properties.connectivityEndpoints.dev
output synapseSqlEndpoint string = synapseWorkspace.properties.connectivityEndpoints.sql
output synapseSqlOnDemandEndpoint string = synapseWorkspace.properties.connectivityEndpoints.sqlOnDemand
output sqlPoolId string = sqlPool.id
output sqlPoolName string = sqlPool.name
output sparkPoolId string = sparkPool.id
output sparkPoolName string = sparkPool.name
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output defaultFileSystemName string = defaultFileSystemName
output workspaceManagedIdentityPrincipalId string = synapseWorkspace.identity.principalId
