@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The name of the Azure Fabric account.')
param fabricAccountName string

@description('The fabric sku.')
@allowed([
  'F2'
  'F4'
  'F8'
  'F16'
  'F32'
  'F64'
  'F128'
  'F256'
  'F512'
  'F1024'
  'F2048'
])
param fabricSku string

@description('The fabric admin id.')
param fabricAdminId string

@description('The tags to be applied to the provisioned resources.')
param tags object


// Please note the usage of feature "#disable-next-line" to suppress warning "BCP073".
// BCP073: The property "friendlyName" is read-only. Expressions cannot be assigned to read-only properties.
resource fabric 'Microsoft.Fabric/capacities@2023-11-01' = {
  name:fabricAccountName
  location: location
  properties: {
    administration: {
      members: [
        fabricAdminId
      ]
    }
  }
  sku: {
    name: fabricSku
    tier: 'Fabric'
  }
  tags: tags
}

output outFabricAccountName string = fabric.name
