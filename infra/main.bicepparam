using './main.bicep'

param resourceGroupName = 'rg-ai-evals'
param location = 'eastus2'
param publicNetworkAccess = 'Enabled'
param disableLocalAuth = true
param azureOpenAIServiceName = 'azureOpenAI-${location}-001'
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

