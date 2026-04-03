@description('The Azure region for the specified resources.')
param location string = resourceGroup().location

@description('The base name to be appended to all provisioned resources.')
@maxLength(13)
param baseName string

@description('Name of the Microsoft Foundry.')
param foundryName string

@description('Name of the Microsoft Foundry Project.')
param foundryProjectName string

@description('The name of the virtual network for virtual network integration.')
param vnetName string

@description('The name of the virtual network subnet to be used for private endpoints.')
param subnetName string

@description('The name of the resource group containing the virtual network.')
param vnetResourceGroupName string

@description('The Private DNS Zone id for the Cognitive Services private endpoint.')
param cognitiveServicesPrivateDnsZoneId string

@description('The Private DNS Zone id for the OpenAI private endpoint.')
param openAiPrivateDnsZoneId string

@description('The user object Id of the user or service principal running the script.')
param objectId string = ''

@description('The  object type User or ServicePrincipal.')
param objectType string = 'User'

@description('The tags to be applied to the provisioned resources.')
param tags object

var privateSubnetId = '${resourceId(vnetResourceGroupName,'Microsoft.Network/virtualNetworks', vnetName)}/subnets/${subnetName}'

/*
  An AI Foundry resources is a variant of a CognitiveServices/account resource type
*/ 
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    // required to work in AI Foundry
    allowProjectManagement: true
    // Defines developer API endpoint subdomain
    customSubDomainName: foundryName

    disableLocalAuth: false
    publicNetworkAccess: 'Disabled'
  }
  tags: tags
}

/*
  Developer APIs are exposed via a project, which groups in- and outputs that relate to one use case, including files.
  Its advisable to create one project right away, so development teams can directly get started.
  Projects may be granted individual RBAC permissions and identities on top of what account provides.
*/ 
resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  name: foundryProjectName
  parent: aiFoundry
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
  tags: tags
  dependsOn: [
    foundryPrivateEndpoint
  ]
}

/*
  Optionally deploy a model to use in playground, agents and other tools.
*/
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01'= {
  parent: aiFoundry
  name: 'gpt-4.1-mini'
  sku : {
    capacity: 1
    name: 'GlobalStandard'
  }
  properties: {
    model:{
      name: 'gpt-4.1-mini'
      format: 'OpenAI'
      version: '2025-04-14'
    }
  }
  tags: tags
  dependsOn: [
    foundryPrivateEndpoint
  ]
}

resource foundryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: 'pe-foundry-${baseName}'
  location: location
  properties: {
    subnet: {
      id: privateSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-foundry-${baseName}'
        properties: {
          privateLinkServiceId: aiFoundry.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }

  resource foundryPrivateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'foundryPrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'cognitiveservices'
          properties: {
            privateDnsZoneId: cognitiveServicesPrivateDnsZoneId
          }
        }
        {
          name: 'openai'
          properties: {
            privateDnsZoneId: openAiPrivateDnsZoneId
          }
        }
      ]
    }
  }
}

// The role definition ID for the Cognitive Services OpenAI User role, which is required to use the Foundry account.
// Must be scoped to the account (not the project) because the data action
// Microsoft.CognitiveServices/accounts/OpenAI/deployments/chat/completions/action lives on the account resource.
var roleCognitiveServicesOpenAIUser = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
resource cognitiveServicesOpenAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry.id, objectId, roleCognitiveServicesOpenAIUser)
  scope: aiFoundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleCognitiveServicesOpenAIUser)
    principalId: objectId
    principalType: objectType
  }
}


output foundryName string = aiFoundry.name
output foundryId string = aiFoundry.id
output foundryPrincipalId string = aiFoundry.identity.principalId
output projectName string = aiProject.name
output projectId string = aiProject.id
output modelDeploymentName string = modelDeployment.name  
output modelDeploymentId string = modelDeployment.id
output modelDeploymentUri string = aiFoundry.properties.endpoint
// If keys are enabled on the Foundry account, they will be output here.
// output modelDeploymentKey string = listKeys(aiFoundry.id, aiFoundry.apiVersion).key1
output modelDeploymentKey string = ''
output modelDeploymentModelApiVersion string = modelDeployment.properties.model.version 
output modelDeploymentModelName string = modelDeployment.properties.model.name