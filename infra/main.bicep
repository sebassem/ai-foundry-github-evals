targetScope = 'managementGroup'

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

@description('GitHub organization name for federated identity')
param githubOrganization string

@description('GitHub repository name for federated identity')
param githubRepository string

@description('GitHub branch name for federated identity')
param githubBranch string

@description('Required. The Azure OpenAI Service models to deploy')
param models array

@description('Subscription ID where the resources will be deployed')
param subscriptionId string

var deployerPrincipal = deployer().objectId

module resourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  scope: subscription(subscriptionId)
  params: {
    name: resourceGroupName
    location: location
  }
}

module azureOpenAIService 'br/public:avm/res/cognitive-services/account:0.11.0' = {
  scope: az.resourceGroup(subscriptionId,resourceGroupName)
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
  scope: az.resourceGroup(subscriptionId,resourceGroupName)
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
  scope: az.resourceGroup(subscriptionId,resourceGroupName)
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
  scope: az.resourceGroup(subscriptionId,resourceGroupName)
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
  scope: az.resourceGroup(subscriptionId,resourceGroupName)
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

module msiRoleAssignment 'br/public:avm/ptn/authorization/role-assignment:0.2.0' = {
  params: {
    principalId: userAssignedIdentity.outputs.principalId
    roleDefinitionIdOrName: 'Contributor'
    description: 'Contributor role for the user assigned identity'
    principalType: 'ServicePrincipal'
    location: location
    subscriptionId: subscriptionId
    resourceGroupName: resourceGroup.outputs.name
  }
}
