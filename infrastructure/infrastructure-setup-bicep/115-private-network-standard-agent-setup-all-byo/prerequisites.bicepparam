using './prerequisites.bicep'

// Location for all resources
param location = 'eastus2'

// Base name for resources - will be combined with unique suffix
// This creates: {baseName}{uniqueSuffix}storage, {baseName}{uniqueSuffix}cosmosdb, {baseName}{uniqueSuffix}search
// Example: 'mycompany-prod' becomes 'mycompany-prodabcdstorstorage', 'mycompany-prodabcdcosmosdb', 'mycompany-prodabcdsearch'
param baseName = 'aiprereqs'

// Virtual Network Configuration
// Customize these to match your naming convention (e.g., 'vnet-prod-agents-001')
param vnetName = 'agent-vnet'
param vnetAddressPrefix = '10.0.0.0/16'

// Agent Subnet Configuration
// Example: 'snet-agents', 'subnet-containerApps', etc.
param agentSubnetName = 'agent-subnet'
param agentSubnetPrefix = '10.0.1.0/24'

// Private Endpoint Subnet Configuration
// Example: 'snet-privateendpoints', 'subnet-pe', etc.
param peSubnetName = 'pe-subnet'
param peSubnetPrefix = '10.0.2.0/24'
