@description('Loation for cross-region AOAI resource.')
param crossRegionLocation string = 'westus'

@description('Name prefix for the Azure OpenAI resource')
param aoaiNamePrefix string = 'aoai'

@description('Unique suffix from main.bicep')
param uniqueSuffix string
var aoaiName = toLower('${aoaiNamePrefix}${uniqueSuffix}')

// Model deployment parameters
@description('The name of the model you want to deploy')
param modelName string = 'gpt-4o'
@description('The provider of your model')
param modelFormat string = 'OpenAI'
@description('The version of your model')
param modelVersion string = '2024-11-20'
@description('The sku of your model deployment')
param modelSkuName string = 'GlobalStandard'
@description('The tokens per minute (TPM) of your model deployment')
param modelCapacity int = 30

#disable-next-line BCP081
resource aoaiResource 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aoaiName
  location: crossRegionLocation
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: aoaiName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

#disable-next-line BCP081
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aoaiResource
  name: modelName
  sku: {
    name: modelSkuName
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: modelFormat
      name: modelName
      version: modelVersion
    }
  }
}
output aoaiResourceId string = aoaiResource.id
output aoaiResourceName string = aoaiResource.name
output aoaiEndpoint string = aoaiResource.properties.endpoint