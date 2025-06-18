using './main.bicep'

param subscriptionId = '2d68328e-bde2-4aeb-a5b4-1a11b4328961'
param resourceGroupName = 'rg-ai-evals-${location}'
param location = 'eastus2'
param publicNetworkAccess = 'Enabled'
param disableLocalAuth = false
param azureOpenAIServiceName = 'azureOpenAI-${location}-${resourceGroupName}'
param foundryHubName = 'hub${location}001'
param foundryProjectName = 'project${location}001'
param githubOrganization = 'sebassem'
param githubRepository = 'ai-foundry-github-evals'
param githubBranch = 'main'
param models = [
  {
    name: 'gpt-4o-mini'
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    sku: {
      capacity: 30
      name: 'GlobalStandard'
    }
  }
  {
    name: 'gpt-4.1-mini'
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1-mini'
      version: '2025-04-14'
    }
    sku: {
      capacity: 30
      name: 'GlobalStandard'
    }
  }
]

