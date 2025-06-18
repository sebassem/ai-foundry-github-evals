targetScope = 'subscription'

param resourceGroupName string = 'rg-${location}-${uniqueString(deployment().name)}'

@description('Location for all resources')
param location string = deployment().location

@description('Public network access for the Azure OpenAI Service and Azure AI Foundry')
param publicNetworkAccess string = 'Enabled'

@description('Disable local authentication for the Azure OpenAI Service')
param disableLocalAuth bool = true

@description('Name for the Azure OpenAI Service')
param azureOpenAIServiceName string = 'azureOpenAI-${location}-${uniqueString(resourceGroupName)}'

@description('Name for the Azure AI Foundry Hub')
param foundryHubName string = 'hub${location}${uniqueString(resourceGroupName)}'

@description('Name for the Azure AI Foundry Project')
param foundryProjectName string = 'project${location}${uniqueString(resourceGroupName)}'

param githubOrganization string

param githubRepository string

param githubBranch string

@description('Optional. The Azure OpenAI Service models to deploy')
param models array = [
  {
    name: 'gpt-4o-mini'
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    sku: {
      capacity: 10
      name: 'GlobalStandard'
    }
  }
  {
    name: 'gpt-4.1-mini'
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1-mini'
      version: '2025-01-01-preview'
    }
    sku: {
      capacity: 10
      name: 'GlobalStandard'
    }
  }
]

var deployerPrincipal = deployer().objectId

module resourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  params: {
    name: 'rg-${location}-${uniqueString(resourceGroupName)}'
    location: location
  }
}

module azureOpenAIService 'br/public:avm/res/cognitive-services/account:0.11.0' = {
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [
    resourceGroup
  ]
  params: {
    name: azureOpenAIServiceName
    kind: 'OpenAI'
    location: location
    managedIdentities: {
      systemAssigned: true
    }
    publicNetworkAccess: publicNetworkAccess
    sku: 'S0'
    deployments: models
    disableLocalAuth: disableLocalAuth
    customSubDomainName: azureOpenAIServiceName
    roleAssignments: [
      {
        principalId: deployerPrincipal
        roleDefinitionIdOrName: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
        principalType: 'User'
        description: 'Cognitive Services OpenAI Contributor'
      }
    ]
  }
}

module azureAIFoundary 'br/public:avm/res/machine-learning-services/workspace:0.12.1' = {
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [
    resourceGroup
  ]
  params: {
    name: foundryHubName
    sku: 'Standard'
    kind: 'Hub'
    publicNetworkAccess: publicNetworkAccess
    systemDatastoresAuthMode: 'Identity'
    location: location
    managedIdentities: {
      systemAssigned: true
    }
    connections: [
      {
        name: 'AzureOpenAI'
        category: 'AzureOpenAI'
        isSharedToAll: true
        connectionProperties: {
          authType: 'AAD'
        }
        metadata: {
          ApiType: 'Azure'
          ResourceId: azureOpenAIService.outputs.resourceId
        }
        target: azureOpenAIService.outputs.endpoint
      }
    ]
  }
}

module azureAIFoundaryProject 'br/public:avm/res/machine-learning-services/workspace:0.12.1' = {
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [
    resourceGroup
  ]
  params: {
    name: foundryProjectName
    sku: 'Standard'
    kind: 'Project'
    location: location
    hubResourceId: azureAIFoundary.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    friendlyName: 'Foundary Project'
    systemDatastoresAuthMode: 'Identity'
    publicNetworkAccess: publicNetworkAccess
    roleAssignments: [
      {
        principalId: deployerPrincipal
        roleDefinitionIdOrName: '64702f94-c441-49e6-a78b-ef80e0188fee'
        principalType: 'User'
        description: 'Azure AI Developer'
      }
    ]
  }
}

module azureAiFoundaryAIRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [
    resourceGroup
  ]
  params: {
    principalId: azureAIFoundary.outputs.?systemAssignedMIPrincipalId ?? ''
    resourceId: azureOpenAIService.outputs.resourceId
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    principalType: 'ServicePrincipal'
    description: 'Reader'
  }
}

module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  scope: az.resourceGroup(resourceGroupName)
  dependsOn: [
    resourceGroup
  ]
  params: {
    name: 'msi-${location}-${uniqueString(resourceGroupName)}'
    location: location
    federatedIdentityCredentials: [
      {
        name: 'azure-openai-federated-identity'
        audiences: [
          'api://AzureADTokenExchange'
        ]
        issuer: 'https://token.actions.githubusercontent.com'
        subject: 'repo:${githubOrganization}/${githubRepository}:ref:refs/heads/${githubBranch}'
      }
    ]
  }
}

module msiRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  scope: az.resourceGroup(resourceGroupName)
  params: {
    principalId: userAssignedIdentity.outputs.principalId
    resourceId: resourceGroup.outputs.resourceId
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalType: 'ServicePrincipal'
    description: 'Contributor role for the user assigned identity'
  }
}
