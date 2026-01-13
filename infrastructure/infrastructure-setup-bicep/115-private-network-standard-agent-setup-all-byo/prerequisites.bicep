/*
Prerequisites Setup - Create resources to be used with main.bicep
This file creates:
  - Virtual Network with 2 subnets (agent subnet and private endpoint subnet)
  - Cosmos DB Account
  - Storage Account
  - AI Search Service

After deployment, use the outputs to populate the existing resource parameters in main.bicep
*/

@description('Location for all resources.')
@allowed([
  'westus'
  'eastus'
  'eastus2'
  'japaneast'
  'francecentral'
  'spaincentral'
  'uaenorth'
  'southcentralus'
  'italynorth'
  'germanywestcentral'
  'brazilsouth'
  'southafricanorth'
  'australiaeast'
  'swedencentral'
  'canadaeast'
  'westeurope'
  'westus3'
  'uksouth'
  'southindia'
  'westus2'
  'northcentralus'
  'canadacentral'
  'eastus2euap'
  'koreacentral'
  'polandcentral'
  'switzerlandnorth'
  'norwayeast'
  'southeastasia'
])
param location string = 'eastus2'

@description('Base name for resources')
param baseName string = 'aiprereqs'

@description('Virtual Network name')
param vnetName string = 'agent-vnet'

@description('Address space for the VNet')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Name of the agent subnet')
param agentSubnetName string = 'agent-subnet'

@description('Address prefix for the agent subnet')
param agentSubnetPrefix string = '10.0.1.0/24'

@description('Name of the private endpoint subnet')
param peSubnetName string = 'pe-subnet'

@description('Address prefix for the private endpoint subnet')
param peSubnetPrefix string = '10.0.2.0/24'

// Create a short, unique suffix
param deploymentTimestamp string = utcNow('yyyyMMddHHmmss')
var uniqueSuffix = substring(uniqueString('${resourceGroup().id}-${deploymentTimestamp}'), 0, 4)
var cosmosDBName = toLower('${baseName}${uniqueSuffix}cosmosdb')
var aiSearchName = toLower('${baseName}${uniqueSuffix}search')
var azureStorageName = toLower('${baseName}${uniqueSuffix}storage')

// Create Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: agentSubnetName
        properties: {
          addressPrefix: agentSubnetPrefix
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: peSubnetName
        properties: {
          addressPrefix: peSubnetPrefix
        }
      }
    ]
  }
}

// Some regions doesn't support Standard Zone-Redundant storage, need to use Geo-redundant storage
param noZRSRegions array = ['southindia', 'westus', 'northcentralus']
param sku object = contains(noZRSRegions, location) ? { name: 'Standard_GRS' } : { name: 'Standard_ZRS' }
// Create Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: azureStorageName
  location: location
  sku: sku
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Disabled'
  }
}

// Create AI Search Service
resource aiSearch 'Microsoft.Search/searchServices@2023-11-01' = {
  name: aiSearchName
  location: location
  sku: {
    name: 'standard'
  }
  properties: {
    disableLocalAuth: false
    authOptions: { aadOrApiKey: { aadAuthFailureMode: 'http401WithBearerChallenge'}}
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'disabled'
    semanticSearch: 'disabled'
    networkRuleSet: {
      bypass: 'None'
      ipRules: []
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Create Cosmos DB Account
var canaryRegions = ['eastus2euap', 'centraluseuap']
var cosmosDbRegion = contains(canaryRegions, location) ? 'westus' : location
resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosDBName
  location: cosmosDbRegion
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: cosmosDbRegion
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    enableFreeTier: false
  }
}

// Outputs to use with main.bicep
output vnetResourceId string = vnet.id
output vnetName string = vnet.name
output agentSubnetName string = agentSubnetName
output peSubnetName string = peSubnetName

output storageAccountResourceId string = storageAccount.id
output storageAccountName string = storageAccount.name

output aiSearchResourceId string = aiSearch.id
output aiSearchName string = aiSearch.name

output cosmosDBResourceId string = cosmosDB.id
output cosmosDBName string = cosmosDB.name

// Output the address prefixes for reference
output vnetAddressPrefix string = vnetAddressPrefix
output agentSubnetPrefix string = agentSubnetPrefix
output peSubnetPrefix string = peSubnetPrefix

// Output formatted for easy copy to main.bicepparam
output mainBicepParamInputs object = {
  existingVnetResourceId: vnet.id
  vnetName: vnet.name
  agentSubnetName: agentSubnetName
  peSubnetName: peSubnetName
  aiSearchResourceId: aiSearch.id
  azureStorageAccountResourceId: storageAccount.id
  azureCosmosDBAccountResourceId: cosmosDB.id
  vnetAddressPrefix: vnetAddressPrefix
  agentSubnetPrefix: agentSubnetPrefix
  peSubnetPrefix: peSubnetPrefix
}
